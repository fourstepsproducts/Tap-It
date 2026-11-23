const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
const dotenv = require('dotenv');

// Load environment variables
dotenv.config();

const connectDB = require('./config/db');

const app = express();

// Middlewares
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Connect Database
connectDB();

// Health check endpoint
app.get('/api/health', (req, res) => {
  const dbStatus = {
    0: 'disconnected',
    1: 'connected',
    2: 'connecting',
    3: 'disconnecting',
  };

  const connectionState = mongoose.connection.readyState;

  res.status(200).json({
    status: 'ok',
    message: 'Tap-It Backend Service is running',
    timestamp: new Date().toISOString(),
    database: {
      status: dbStatus[connectionState] || 'unknown',
      readyState: connectionState,
    },
  });
});

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

module.exports = app;
