% Motor de facturacion - SC-250 Paradigmas de Programacion.
% Las tarifas son DIDACTICAS, indicadas por el profesor.
% No se debe usar como sistema tributario real sin validar con Hacienda.
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(http/json)).
:- dynamic producto/5, kit/2, cliente/4, factura/3, linea/3, estado_guardado/2.

iva_categoria(general, 13).
iva_categoria(medicamento, 2).
iva_categoria(canasta, 1).
iva_categoria(exento, 0).

descuento_volumen(Cantidad, 10) :- Cantidad >= 50, !.
descuento_volumen(Cantidad, 5) :- Cantidad >= 10, !.
descuento_volumen(_, 0).

descuento_nivel(oro, 10).
descuento_nivel(plata, 5).
descuento_nivel(regular, 0).

% Los kits pueden contener otros kits. El argumento Visitados impide ciclos.
precio_item(Codigo, Precio, Categoria) :-
    precio_item_visitado(Codigo, [], Precio, Categoria).
precio_item_visitado(Codigo, _, Precio, Categoria) :-
    producto(Codigo, _, Categoria, Precio, _), !.
precio_item_visitado(Codigo, Visitados, Precio, general) :-
    kit(Codigo, Componentes),
    \+ memberchk(Codigo, Visitados),
    precios_componentes(Componentes, [Codigo|Visitados], Precios),
    sum_list(Precios, Suma),
    Precio is Suma * 0.95.
precios_componentes([], _, []).
precios_componentes([Codigo|Resto], Visitados, [Precio|Precios]) :-
    precio_item_visitado(Codigo, Visitados, Precio, _),
    precios_componentes(Resto, Visitados, Precios).

% Expansion para verificar stock real de productos dentro de kits anidados.
componentes_base(Codigo, Componentes) :-
    componentes_base(Codigo, [], Componentes).
componentes_base(Codigo, _, [Codigo-1]) :-
    producto(Codigo, _, _, _, _), !.
componentes_base(Codigo, Visitados, Componentes) :-
    kit(Codigo, Items),
    \+ memberchk(Codigo, Visitados),
    componentes_lista(Items, [Codigo|Visitados], Componentes).
componentes_lista([], _, []).
componentes_lista([Codigo|Resto], Visitados, Componentes) :-
    componentes_base(Codigo, Visitados, C1),
    componentes_lista(Resto, Visitados, C2),
    append(C1, C2, Componentes).

cantidad_requerida(Factura, Producto, Cantidad) :-
    findall(Unidades,
        (linea(Factura, Item, Num), integer(Num), Num > 0,
         componentes_base(Item, Componentes),
         member(Producto-Multiplicador, Componentes),
         Unidades is Num * Multiplicador),
        Requeridas),
    sum_list(Requeridas, Cantidad),
    Cantidad > 0.

% Mensajes explicativos. Cada regla distinta se incluye como un termino.
error_de_factura(Id, sin_lineas) :-
    factura(Id, _, _), \+ linea(Id, _, _).
error_de_factura(Id, cantidad_invalida(Codigo, Cantidad)) :-
    linea(Id, Codigo, Cantidad), (\+ integer(Cantidad) ; Cantidad =< 0).
error_de_factura(Id, item_desconocido(Codigo)) :-
    linea(Id, Codigo, _),
    \+ producto(Codigo, _, _, _, _), \+ kit(Codigo, _).
error_de_factura(Id, kit_invalido(Codigo)) :-
    linea(Id, Codigo, _), kit(Codigo, _),
    \+ componentes_base(Codigo, _).
error_de_factura(Id, stock_insuficiente(Codigo, Necesario, Disponible)) :-
    producto(Codigo, _, _, _, Disponible),
    cantidad_requerida(Id, Codigo, Necesario),
    Necesario > Disponible.
error_de_factura(Id, cliente_desconocido(Codigo)) :-
    factura(Id, Codigo, _), \+ cliente(Codigo, _, _, _).
error_de_factura(Id, credito_consumidor_final) :-
    factura(Id, Cliente, credito),
    cliente(Cliente, _, consumidor_final, _).
error_de_factura(Id, credito_nivel_regular) :-
    factura(Id, Cliente, credito),
    cliente(Cliente, _, _, regular).

mensaje_error(sin_lineas, "La factura no tiene lineas de productos.").
mensaje_error(cantidad_invalida(C, N), M) :-
    format(string(M), "La cantidad de ~w no es valida: ~w. Debe ser un entero positivo.", [C,N]).
mensaje_error(item_desconocido(C), M) :-
    format(string(M), "No existe el producto o kit ~w.", [C]).
mensaje_error(kit_invalido(C), M) :-
    format(string(M), "El kit ~w contiene componentes inexistentes o una referencia circular.", [C]).
mensaje_error(stock_insuficiente(C, N, Stock), M) :-
    format(string(M), "Stock insuficiente de ~w: requiere ~w unidades y hay ~w.", [C,N,Stock]).
mensaje_error(cliente_desconocido(C), M) :-
    format(string(M), "El cliente ~w no existe.", [C]).
mensaje_error(credito_consumidor_final,
    "No se permite credito a clientes de tipo consumidor final.").
mensaje_error(credito_nivel_regular,
    "No se permite credito a clientes de nivel regular.").

errores_factura(Id, Mensajes) :-
    findall(Error, error_de_factura(Id, Error), Errores),
    sort(Errores, Unicos),
    maplist(mensaje_error, Unicos, Mensajes).

nombre_item(Codigo, Nombre) :- producto(Codigo, Nombre, _, _, _), !.
nombre_item(Codigo, Codigo) :- kit(Codigo, _).

detalle_linea(Id, Nivel, Exonerado, Detalle) :-
    linea(Id, Codigo, Cantidad),
    precio_item(Codigo, Precio, Categoria),
    nombre_item(Codigo, Nombre),
    descuento_volumen(Cantidad, DV),
    descuento_nivel(Nivel, DC),
    Base is round(Precio * Cantidad * (100-DV) / 100 * (100-DC) / 100),
    ( Exonerado == si -> Tarifa = 0 ; iva_categoria(Categoria, Tarifa) ),
    Impuesto is round(Base * Tarifa / 100),
    Total is Base + Impuesto,
    format(string(Explicacion),
        "Cantidad ~w; descuento volumen ~w%; descuento cliente ~w%; IVA ~w%.",
        [Cantidad,DV,DC,Tarifa]),
    Detalle = _{codigo:Codigo, nombre:Nombre, categoria:Categoria,
                cantidad:Cantidad, precioUnitario:Precio,
                descuentoVolumen:DV, descuentoCliente:DC,
                base:Base, tarifaIva:Tarifa, iva:Impuesto, total:Total,
                explicacion:Explicacion}.

sumar_campo(Lista, Campo, Total) :-
    findall(X, (member(D, Lista), get_dict(Campo, D, X)), Valores),
    sum_list(Valores, Total).

calcular_factura(Id, Resultado) :-
    (   factura(Id, ClienteId, _)
    ->  errores_factura(Id, Errores),
        (   Errores == []
        ->  cliente(ClienteId, _, Tipo, Nivel),
            (Tipo == exonerado -> Exonerado = si ; Exonerado = no),
            findall(Detalle, detalle_linea(Id, Nivel, Exonerado, Detalle), Detalles),
            sumar_campo(Detalles, base, Subtotal),
            sumar_campo(Detalles, iva, IVA),
            Total is Subtotal + IVA,
            Resultado = _{id:Id, estado:emitida, subtotal:Subtotal,
                          iva:IVA, total:Total, errores:[], detalles:Detalles}
        ;   Resultado = _{id:Id, estado:rechazada, subtotal:0,
                          iva:0, total:0, errores:Errores, detalles:[]}
        )
    ;   Resultado = _{id:Id, estado:rechazada, subtotal:0,
                      iva:0, total:0, errores:["Factura inexistente."], detalles:[]}
    ).

% Si llegan estados persistidos desde Neon solo se reportan las realmente
% emitidas. Si se usan los datos academicos sin estado, se toman las validas.
factura_reportable(Id, Resultado) :-
    factura(Id, _, _),
    ( estado_guardado(_, _) -> estado_guardado(Id, emitida) ; true ),
    calcular_factura(Id, Resultado),
    Resultado.estado == emitida.

unidades_vendidas(Codigo, Cantidad) :-
    producto(Codigo, _, _, _, _),
    findall(Unidades,
        (factura_reportable(Id, _), cantidad_requerida(Id, Codigo, Unidades)),
        Lista),
    sum_list(Lista, Cantidad).

producto_mas_vendido(Codigo, Cantidad) :-
    findall(Neg-C, (producto(C,_,_,_,_), unidades_vendidas(C,N), Neg is -N), Pares),
    keysort(Pares, [NegCantidad-Codigo|_]),
    Cantidad is -NegCantidad.

siguiente_consecutivo(Consecutivo) :-
    findall(Id, factura(Id, _, _), Numeros),
    ( Numeros == [] -> Consecutivo = 1 ; max_list(Numeros, Max), Consecutivo is Max+1 ).

reporte_tarifa(Tarifa, Reporte) :-
    findall(Detalle,
        (factura_reportable(_, Fact), member(Detalle, Fact.detalles),
         Detalle.tarifaIva =:= Tarifa),
        Lineas),
    sumar_campo(Lineas, base, Base),
    sumar_campo(Lineas, iva, IVA),
    Reporte = _{tarifa:Tarifa, base:Base, iva:IVA}.

calcular_reportes(Resultado) :-
    findall(F, factura_reportable(_, F), Facturas),
    sumar_campo(Facturas, subtotal, Subtotal),
    sumar_campo(Facturas, iva, IVA),
    Total is Subtotal + IVA,
    findall(_{codigo:C, unidades:N},
        (producto(C,_,_,_,_), unidades_vendidas(C,N)), Unidades),
    ( producto_mas_vendido(Codigo, UnidadesMax)
    -> MasVendido = _{codigo:Codigo, unidades:UnidadesMax}
    ;  MasVendido = null
    ),
    siguiente_consecutivo(Siguiente),
    maplist(reporte_tarifa, [13,2,1,0], Tarifas),
    Resultado = _{ventasTotales:Total, subtotal:Subtotal, ivaPorPagar:IVA,
                  unidadesPorProducto:Unidades, productoMasVendido:MasVendido,
                  siguienteConsecutivo:Siguiente, ventasPorTarifa:Tarifas}.

% Puente JSON para integracion con la API de Node. Los datos reales se leen
% desde Neon por la API y se transmiten a SWI-Prolog por stdin.
a_atomo(V, A) :- atom(V), !, A = V.
a_atomo(V, A) :- string(V), !, atom_string(A, V).
limpiar_datos :-
    retractall(producto(_,_,_,_,_)), retractall(kit(_,_)),
    retractall(cliente(_,_,_,_)), retractall(factura(_,_,_)),
    retractall(linea(_,_,_)), retractall(estado_guardado(_,_)).

cargar_datos(Datos) :-
    limpiar_datos,
    forall(member(P, Datos.productos),
      (a_atomo(P.cod,C), a_atomo(P.nombre,N), a_atomo(P.categoria,Cat),
       assertz(producto(C,N,Cat,P.precio,P.stock)))),
    forall(member(K, Datos.kits),
      (a_atomo(K.cod,C), maplist(a_atomo, K.componentes, Componentes),
       assertz(kit(C,Componentes)))),
    forall(member(Cli, Datos.clientes),
      (a_atomo(Cli.id,Id), a_atomo(Cli.nombre,N), a_atomo(Cli.tipo,T),
       a_atomo(Cli.nivel,L), assertz(cliente(Id,N,T,L)))),
    forall(member(F, Datos.facturas),
      (a_atomo(F.cliente_id,Cliente), a_atomo(F.forma_pago,Pago),
       assertz(factura(F.id,Cliente,Pago)),
       (get_dict(estado, F, E), E \== null
         -> a_atomo(E,Estado), assertz(estado_guardado(F.id, Estado))
         ; true))),
    forall(member(L, Datos.lineas),
      (a_atomo(L.producto_cod,C),
       assertz(linea(L.factura_id,C,L.cantidad)))).

main :-
    catch(
      (json_read_dict(user_input, Solicitud),
       cargar_datos(Solicitud.datos),
       (Solicitud.accion == "reportes" -> calcular_reportes(R)
       ; Solicitud.accion == "factura" -> calcular_factura(Solicitud.factura_id, R)
       ; throw(error(accion_invalida, _))),
       json_write_dict(current_output, R), nl),
      Error,
      (message_to_string(Error, M),
       json_write_dict(current_output, _{error:M}), nl,
       halt(1))).
