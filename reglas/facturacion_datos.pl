
% DATOS de ejemplo para el sistema de facturacion
% producto(Cod, Nombre, Categoria, Precio, Stock)

producto(p1, arroz_1kg, canasta, 1200, 200).
producto(p2, laptop, general, 450000, 15).
producto(p3, paracetamol, medicamento, 1500, 500).
producto(p4, mouse, general, 8500, 80).
producto(p5, hora_soporte, general, 25000, 9999).
producto(p6, libro_texto, exento, 12000, 30).
producto(p7, teclado, general, 18000, 40).

% Kits de productos
% kit(Cod, [Componentes])

kit(k1, [p2, p4, p7]).
kit(k2, [k1, p5]).

% Clientes
% cliente(Id, Nombre, Tipo, Nivel)

cliente(c1, tienda_sol, contribuyente, oro).
cliente(c2, juan_perez, consumidor_final, regular).
cliente(c3, fundacion_esperanza, exonerado, plata).
cliente(c4, comercial_luna, contribuyente, regular).

% Facturas
% factura(Id, Cliente, FormaPago)

factura(1, c1, contado).
factura(2, c2, contado).
factura(3, c3, contado).
factura(4, c4, credito).
factura(5, c2, contado).
factura(6, c1, credito).

% Lineas de facturacion
% linea(Factura, Producto, Cantidad)

linea(1, p2, 2).
linea(1, p4, 12).
linea(1, p5, 3).

linea(2, p1, 10).
linea(2, p3, 2).
linea(2, p6, 1).

linea(3, p2, 1).
linea(3, p7, 10).

linea(4, p4, 5).

linea(5, p2, 20).

linea(6, k2, 1).
