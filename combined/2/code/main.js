const express = require('express');
const mysql = require('mysql2');

const app = express();
const port = 80;

app.get('/envs', (req, res) => {
  res.json(process.env);
});

app.get('/health', (req, res) => {
  res.json({ status: 'OK' });
});

app.get('/db', (req, res) => {
  try {
    const dbSecrets = JSON.parse(process.env.DB_SECRETS);
    console.log(dbSecrets);
    const connection = mysql.createConnection({
      host: process.env.DB_HOST,
      user: dbSecrets.username,
      database: process.env.DB_NAME,
      ssl: 'Amazon RDS',
      password: dbSecrets.password
    });
    
    connection.connect(err => {
      if (err) {
        console.error('Error connecting: ' + err.stack);
        res.send(err);
      } else {
        console.log('Connected as id ' + connection.threadId);
        res.send('OK');
      }
    });
    
  } catch (e) {
    res.send(e);
  }
});

app.listen(port, () => {
  console.log(`App listening at http://localhost:${port}`);
});
