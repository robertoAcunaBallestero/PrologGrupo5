
% Archivo de demostracion del sistema de facturacion

:- ['motor.pl'].
:- ['facturacion_datos.pl'].

% Consultar una factura
ver_factura(Id, Resultado) :-
    calcular_factura(Id, Resultado).

% Consultar reportes
ver_reportes(Resultado) :-
    calcular_reportes(Resultado).
