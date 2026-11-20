
"use strict";

// SISTEMA DE FACTURACION PROLOG
// Universidad Fidelitas

const datos = {
    productos: [],
    clientes: [],
    kits: [],
    facturas: []
};

const $ = id => document.getElementById(id);

const colones = valor =>
    new Intl.NumberFormat("es-CR", {
        style: "currency",
        currency: "CRC",
        maximumFractionDigits: 0
    }).format(Number(valor) || 0);

// Comunicacion con el backend
async function api(ruta, opciones = {}) {
    const respuesta = await fetch("/api" + ruta, {
        ...opciones,
        headers: {
            "Content-Type": "application/json",
            ...opciones.headers
        }
    });

    const resultado = await respuesta.json()
        .catch(() => null);

    if (!respuesta.ok) {
        const error = new Error(
            resultado?.error ||
            resultado?.mensaje ||
            "Error HTTP " + respuesta.status
        );
        error.status = respuesta.status;
        throw error;
    }

    return resultado;
}

function mostrarAlerta(mensaje, error = false) {
    const alerta = $("alerta");
    alerta.textContent = mensaje;
    alerta.className = error ? "error" : "exito";
}

// Navegacion entre secciones
async function mostrarSeccion(nombre) {
    for (const seccion of document.querySelectorAll("main section")) {
        seccion.hidden = seccion.id !== nombre;
    }

    try {
        if (nombre === "productos") {
            mostrarProductos();
        }

        if (nombre === "historial") {
            await cargarHistorial();
        }

        if (nombre === "reportes") {
            await cargarReportes();
        }
    } catch (error) {
        mostrarAlerta(error.message, true);
    }
}

// Crear una celda de tabla
function celda(fila, valor) {
    const td = document.createElement("td");
    td.textContent = String(valor ?? "-");
    fila.appendChild(td);
}

// Mostrar catalogo de productos
function mostrarProductos() {
    const tabla = $("tablaProductos");
    tabla.replaceChildren();

    for (const producto of datos.productos) {
        const fila = document.createElement("tr");

        celda(fila, producto.cod);
        celda(fila, producto.nombre);
        celda(fila, producto.categoria);
        celda(fila, colones(producto.precio));
        celda(fila, producto.stock);

        tabla.appendChild(fila);
    }
}

// Preparar clientes
function cargarSelectoresClientes() {
    const selectCliente = $("cliente");
    const filtroCliente = $("filtroCliente");

    selectCliente.replaceChildren();
    filtroCliente.replaceChildren();

    const todos = document.createElement("option");
    todos.value = "";
    todos.textContent = "Todos";
    filtroCliente.appendChild(todos);

    for (const cliente of datos.clientes) {
        for (const select of [selectCliente, filtroCliente]) {
            const opcion = document.createElement("option");
            opcion.value = cliente.id;
            opcion.textContent = cliente.nombre;
            select.appendChild(opcion);
        }
    }
}

// Productos y kits disponibles
function obtenerOpciones() {
    const productos = datos.productos.map(p => ({
        codigo: p.cod,
        nombre: p.nombre,
        precio: Number(p.precio),
        esKit: false
    }));

    const kitsUnicos = new Map();

    for (const kit of datos.kits) {
        kitsUnicos.set(kit.cod, {
            codigo: kit.cod,
            nombre: kit.nombre || kit.cod,
            precio: 0,
            esKit: true
        });
    }

    return [...productos, ...kitsUnicos.values()];
}

// Agregar una linea a la factura
function agregarLinea() {
    const opciones = obtenerOpciones();

    if (!opciones.length) {
        mostrarAlerta("No hay productos disponibles.", true);
        return;
    }

    const contenedor = document.createElement("div");
    contenedor.className = "linea";

    const select = document.createElement("select");
    select.className = "producto";
    select.setAttribute("aria-label", "Producto");

    for (const producto of opciones) {
        const opcion = document.createElement("option");
        opcion.value = producto.codigo;
        opcion.textContent =
            producto.codigo + " - " + producto.nombre;
        select.appendChild(opcion);
    }

    const cantidad = document.createElement("input");
    cantidad.type = "number";
    cantidad.className = "cantidad";
    cantidad.min = "1";
    cantidad.step = "1";
    cantidad.value = "1";
    cantidad.required = true;

    const eliminar = document.createElement("button");
    eliminar.type = "button";
    eliminar.textContent = "Eliminar";

    eliminar.addEventListener("click", () => {
        contenedor.remove();
        actualizarEstimado();
    });

    select.addEventListener("change", actualizarEstimado);
    cantidad.addEventListener("input", actualizarEstimado);

    contenedor.append(select, cantidad, eliminar);
    $("lineas").appendChild(contenedor);

    actualizarEstimado();
}

// Calcular subtotal orientativo
function actualizarEstimado() {
    const opciones = obtenerOpciones();
    let subtotal = 0;
    let tieneKits = false;

    for (const linea of document.querySelectorAll(".linea")) {
        const codigo = linea.querySelector(".producto").value;
        const cantidad = Number(
            linea.querySelector(".cantidad").value
        );

        const producto = opciones.find(
            p => p.codigo === codigo
        );

        if (!producto || !Number.isInteger(cantidad) ||
            cantidad < 1) continue;

        if (producto.esKit) {
            tieneKits = true;
        } else {
            subtotal += producto.precio * cantidad;
        }
    }

    $("estimado").textContent =
        colones(subtotal) +
        (tieneKits ? " + kits pendientes de calcular" : "") +
        " (sin descuentos ni IVA)";
}

// Crear y emitir factura
async function guardarFactura(evento) {
    evento.preventDefault();

    const lineas = [];

    for (const fila of document.querySelectorAll(".linea")) {
        const codigo = fila.querySelector(".producto").value;
        const cantidad = Number(
            fila.querySelector(".cantidad").value
        );

        if (!Number.isInteger(cantidad) || cantidad < 1) {
            mostrarAlerta("Cantidad invalida.", true);
            return;
        }

        lineas.push({ codigo, cantidad });
    }

    if (lineas.length === 0) {
        mostrarAlerta("Agrega al menos un producto.", true);
        return;
    }

    const factura = {
        clienteId: $("cliente").value,
        formaPago: $("formaPago").value,
        lineas
    };

    const boton = $("guardar");
    boton.disabled = true;

    try {
        const resultado = await api("/facturas/emitir", {
            method: "POST",
            body: JSON.stringify(factura)
        });

        const salida = document.createElement("pre");
        salida.textContent = JSON.stringify(resultado, null, 2);

        $("resultado").replaceChildren(salida);
        mostrarAlerta("Solicitud de factura procesada.");

    } catch (error) {
        if (error.status === 404) {
            mostrarAlerta(
                "Falta implementar la emision en el backend.",
                true
            );
        } else {
            mostrarAlerta(error.message, true);
        }
    } finally {
        boton.disabled = false;
    }
}

// Consultar historial
async function cargarHistorial() {
    datos.facturas = await api("/facturas");
    mostrarHistorial();
}

function mostrarHistorial() {
    const tabla = $("tablaFacturas");
    tabla.replaceChildren();

    const estado = $("filtroEstado").value;
    const cliente = $("filtroCliente").value;

    const facturas = datos.facturas.filter(f =>
        (!estado || f.estado === estado) &&
        (!cliente || String(f.cliente_id) === cliente)
    );

    for (const factura of facturas) {
        const fila = document.createElement("tr");

        celda(fila, factura.id);
        celda(fila, factura.cliente_id ?? factura.cliente);
        celda(fila, factura.estado);
        celda(
            fila,
            factura.total == null ? "-" : colones(factura.total)
        );

        const td = document.createElement("td");
        const boton = document.createElement("button");

        boton.textContent = "Ver lineas";
        boton.addEventListener("click", () =>
            consultarLineas(factura.id)
        );

        td.appendChild(boton);
        fila.appendChild(td);
        tabla.appendChild(fila);
    }
}

// Consultar lineas de una factura
async function consultarLineas(id) {
    try {
        const lineas = await api(
            "/facturas/" + encodeURIComponent(id) + "/lineas"
        );

        const salida = document.createElement("pre");
        salida.textContent = JSON.stringify(lineas, null, 2);

        $("detalleFactura").replaceChildren(salida);
    } catch (error) {
        mostrarAlerta(error.message, true);
    }
}

// Consultar reportes
async function cargarReportes() {
    try {
        const reporte = await api("/reportes");

        $("estadisticas").replaceChildren();
        $("grafico").replaceChildren();
        $("tarifas").replaceChildren();

        const resumen = document.createElement("div");
        resumen.className = "tarjeta";

        resumen.textContent =
            "Ventas totales: " + colones(reporte.ventasTotales) +
            " | Subtotal: " + colones(reporte.subtotal) +
            " | IVA: " + colones(reporte.ivaPorPagar);

        $("estadisticas").appendChild(resumen);

        const productos = reporte.unidadesPorProducto || [];
        const maximo = Math.max(
            1,
            ...productos.map(p => Number(p.unidades))
        );

        for (const producto of productos) {
            const barra = document.createElement("div");
            barra.className = "barra";
            barra.style.width =
                Math.max(15, producto.unidades / maximo * 100) + "%";

            barra.textContent =
                producto.codigo + ": " + producto.unidades;

            $("grafico").appendChild(barra);
        }

        for (const tarifa of reporte.ventasPorTarifa || []) {
            const elemento = document.createElement("p");
            elemento.textContent =
                "IVA " + tarifa.tarifa + "%: " +
                colones(tarifa.iva) +
                " | Base: " + colones(tarifa.base);

            $("tarifas").appendChild(elemento);
        }

    } catch (error) {
        if (error.status === 404) {
            $("estadisticas").textContent =
                "Los reportes de la API estan pendientes.";
        } else {
            mostrarAlerta(error.message, true);
        }
    }
}

// Inicio del sistema
async function iniciar() {
    $("agregar").addEventListener("click", agregarLinea);

    $("formFactura").addEventListener("submit", guardarFactura);

    $("filtroEstado").addEventListener(
        "change", mostrarHistorial
    );

    $("filtroCliente").addEventListener(
        "change", mostrarHistorial
    );

    try {
        const [productos, clientes, kits] = await Promise.all([
            api("/productos"),
            api("/clientes"),
            api("/kits")
        ]);

        datos.productos = productos;
        datos.clientes = clientes;
        datos.kits = kits;

        cargarSelectoresClientes();
        mostrarProductos();
        agregarLinea();

        mostrarAlerta("Datos cargados correctamente.");

    } catch (error) {
        mostrarAlerta(
            "Error al cargar datos: " + error.message,
            true
        );
    }
}

document.addEventListener("DOMContentLoaded", iniciar);
