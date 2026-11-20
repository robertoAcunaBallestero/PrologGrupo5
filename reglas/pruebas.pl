:- ['motor.pl'].
:- ['facturacion_datos.pl'].
:- use_module(library(plunit)).

:- begin_tests(facturacion).
test(tarifa_general) :- iva_categoria(general,13).
test(tarifa_medicamento) :- iva_categoria(medicamento,2).
test(tarifa_canasta) :- iva_categoria(canasta,1).
test(tarifa_exento) :- iva_categoria(exento,0).
test(volumen_cero) :- descuento_volumen(9,0).
test(volumen_cinco) :- descuento_volumen(10,5).
test(volumen_diez) :- descuento_volumen(50,10).
test(descuento_oro) :- descuento_nivel(oro,10).
test(descuento_plata) :- descuento_nivel(plata,5).
test(precio_kit_simple) :-precio_item(k1, P, general),P =:= 452675.

test(precio_kit_anidado) :- precio_item(k2,P,general), abs(P-453791.25)<0.001.
test(factura_2_subtotal) :- calcular_factura(2,R), R.subtotal =:= 26400.
test(factura_2_iva) :- calcular_factura(2,R), R.iva =:= 174.
test(factura_2_total) :- calcular_factura(2,R), R.total =:= 26574.
test(factura_3_exonerada) :- calcular_factura(3,R), R.iva =:= 0, R.total =:= 589950.
test(factura_1_total) :- calcular_factura(1,R), R.total =:= 1090122.
test(factura_4_rechazada_credito) :-
    calcular_factura(4,R), R.estado == rechazada,
    member("No se permite credito a clientes de nivel regular.", R.errores).
test(factura_5_rechazada_stock) :-
    calcular_factura(5,R), R.estado == rechazada, R.errores \== [].
test(factura_6_kit_recursivo) :- calcular_factura(6,R), R.total =:= 461506.
test(siguiente_consecutivo) :- siguiente_consecutivo(7).
test(unidades_dentro_de_kits) :- unidades_vendidas(p4,13).
test(producto_top) :- producto_mas_vendido(p4,13).
test(reporte_iva) :- calcular_reportes(R), R.ivaPorPagar =:= 178680.
test(reporte_ventas) :- calcular_reportes(R), R.ventasTotales =:= 2168152.
test(cantidad_no_positiva,
     [setup((assertz(factura(90,c1,contado)),assertz(linea(90,p1,0)))),
      cleanup((retractall(linea(90,_,_)),retractall(factura(90,_,_))))]) :-
    calcular_factura(90,R), R.estado == rechazada.
test(sin_lineas,
     [setup(assertz(factura(91,c1,contado))),
      cleanup(retractall(factura(91,_,_)))]) :-
    calcular_factura(91,R), R.estado == rechazada.
:- end_tests(facturacion).

:- initialization(run_tests, main).
