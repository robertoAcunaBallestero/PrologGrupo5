-- Sistema de facturación · esquema y datos de ejemplo para PostgreSQL (Neon)
-- Ejecutar completo en Neon: SQL Editor -> pegar -> Run.
CREATE TABLE IF NOT EXISTS productos (
  cod        TEXT PRIMARY KEY,
  nombre     TEXT    NOT NULL,
  categoria  TEXT    NOT NULL CHECK (categoria IN ('general','medicamento','canasta','exento')),
  precio     INTEGER NOT NULL CHECK (precio > 0),
  stock      INTEGER NOT NULL CHECK (stock >= 0)
);

-- Un kit agrupa productos u otros kits (item_cod puede ser un producto o un kit)
CREATE TABLE IF NOT EXISTS kits (
  cod     TEXT PRIMARY KEY,
  nombre  TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS kit_items (
  kit_cod  TEXT NOT NULL REFERENCES kits(cod) ON DELETE CASCADE,
  item_cod TEXT NOT NULL,
  PRIMARY KEY (kit_cod, item_cod)
);

CREATE TABLE IF NOT EXISTS clientes (
  id      TEXT PRIMARY KEY,
  nombre  TEXT NOT NULL,
  tipo    TEXT NOT NULL CHECK (tipo IN ('contribuyente','consumidor_final','exonerado')),
  nivel   TEXT NOT NULL CHECK (nivel IN ('oro','plata','regular'))
);

CREATE TABLE IF NOT EXISTS facturas (
  id          SERIAL PRIMARY KEY,
  cliente_id  TEXT NOT NULL REFERENCES clientes(id),
  forma_pago  TEXT NOT NULL CHECK (forma_pago IN ('contado','credito')),
  estado      TEXT,            -- emitida / rechazada: la calcula el motor de reglas en Prolog
  errores     TEXT,
  subtotal    INTEGER,
  iva         INTEGER,
  total       INTEGER,
  creada_en   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS lineas (
  id           SERIAL PRIMARY KEY,
  factura_id   INTEGER NOT NULL REFERENCES facturas(id) ON DELETE CASCADE,
  producto_cod TEXT    NOT NULL,
  cantidad     INTEGER NOT NULL
);

INSERT INTO productos (cod, nombre, categoria, precio, stock) VALUES
 ('p1','arroz_1kg','canasta',1200,200),
 ('p2','laptop','general',450000,15),
 ('p3','paracetamol','medicamento',1500,500),
 ('p4','mouse','general',8500,80),
 ('p5','hora_soporte','general',25000,9999),
 ('p6','libro_texto','exento',12000,30),
 ('p7','teclado','general',18000,40)
ON CONFLICT (cod) DO NOTHING;

INSERT INTO kits (cod, nombre) VALUES ('k1','kit_oficina'),('k2','kit_oficina_con_soporte') ON CONFLICT (cod) DO NOTHING;
INSERT INTO kit_items (kit_cod, item_cod) VALUES ('k1','p2'),('k1','p4'),('k1','p7'),('k2','k1'),('k2','p5') ON CONFLICT DO NOTHING;

INSERT INTO clientes (id, nombre, tipo, nivel) VALUES
 ('c1','tienda_sol','contribuyente','oro'),
 ('c2','juan_perez','consumidor_final','regular'),
 ('c3','fundacion_esperanza','exonerado','plata'),
 ('c4','comercial_luna','contribuyente','regular')
ON CONFLICT (id) DO NOTHING;

INSERT INTO facturas (id, cliente_id, forma_pago) VALUES
 (1,'c1','contado'),(2,'c2','contado'),(3,'c3','contado'),(4,'c4','credito'),(5,'c2','contado'),(6,'c1','credito')
ON CONFLICT (id) DO NOTHING;

INSERT INTO lineas (factura_id, producto_cod, cantidad) VALUES
 (1,'p2',2),(1,'p4',12),(1,'p5',3),
 (2,'p1',10),(2,'p3',2),(2,'p6',1),
 (3,'p2',1),(3,'p7',10),
 (4,'p4',5),
 (5,'p2',20),
 (6,'k2',1);

SELECT setval(pg_get_serial_sequence('facturas','id'), (SELECT MAX(id) FROM facturas));
