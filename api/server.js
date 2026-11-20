
'use strict';

require('dotenv').config();

const express = require('express');
const { Pool } = require('pg');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const app = express();

app.use(express.json({ limit: '256kb' }));

const MOTOR_PATH = path.resolve(
  __dirname,
  '../reglas/motor.pl'
);

const WEB_PATH = path.resolve(__dirname, '../web');

const SWIPL_BIN = process.env.SWIPL_BIN ||
  (
    process.platform === 'win32' &&
    fs.existsSync('C:\\Program Files\\swipl\\bin\\swipl.exe')
      ? 'C:\\Program Files\\swipl\\bin\\swipl.exe'
      : 'swipl'
  );

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 5
});

// Consultar productos
app.get('/api/productos', async (req, res) => {
  try {
    const resultado = await pool.query(
      'SELECT * FROM productos ORDER BY cod'
    );
    res.json(resultado.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Consultar clientes
app.get('/api/clientes', async (req, res) => {
  try {
    const resultado = await pool.query(
      'SELECT * FROM clientes ORDER BY id'
    );
    res.json(resultado.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Consultar kits
app.get('/api/kits', async (req, res) => {
  try {
    const resultado = await pool.query(
      `SELECT k.cod, k.nombre, ki.item_cod
       FROM kits k
       LEFT JOIN kit_items ki ON ki.kit_cod = k.cod
       ORDER BY k.cod, ki.item_cod`
    );
    res.json(resultado.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Consultar facturas
app.get('/api/facturas', async (req, res) => {
  try {
    const resultado = await pool.query(
      'SELECT * FROM facturas ORDER BY id'
    );
    res.json(resultado.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Consultar lineas de una factura
app.get('/api/facturas/:id/lineas', async (req, res) => {
  try {
    const resultado = await pool.query(
      `SELECT * FROM lineas
       WHERE factura_id = $1
       ORDER BY id`,
      [req.params.id]
    );
    res.json(resultado.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Funcion para ejecutar Prolog
function ejecutarProlog(consulta) {
  return new Promise((resolve, reject) => {

    const proceso = spawn(SWIPL_BIN, [
      '-q',
      '-s', MOTOR_PATH,
      '-g', consulta,
      '-t', 'halt'
    ]);

    let salida = '';
    let errores = '';

    proceso.stdout.on('data', dato => {
      salida += dato.toString();
    });

    proceso.stderr.on('data', dato => {
      errores += dato.toString();
    });

    proceso.on('error', reject);

    proceso.on('close', codigo => {
      if (codigo === 0) {
        resolve(salida);
      } else {
        reject(new Error(errores));
      }
    });
  });
}

// Verificar conexion de Neon
app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');

    res.json({
      estado: 'ok',
      baseDatos: 'conectada',
      prolog: SWIPL_BIN
    });

  } catch (error) {
    res.status(500).json({
      estado: 'error',
      mensaje: error.message
    });
  }
});

// Servir interfaz web
app.use(express.static(WEB_PATH));

// Iniciar servidor
const PORT = process.env.PORT || 3000;

if (!process.env.DATABASE_URL) {
  console.error(
    'Falta configurar DATABASE_URL en el archivo .env'
  );
  process.exit(1);
}

app.listen(PORT, () => {
  console.log(
    `Servidor iniciado en http://localhost:${PORT}`
  );
});
