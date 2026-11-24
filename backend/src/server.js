const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
const dotenv = require('dotenv');

// Load environment variables
dotenv.config();

const connectDB = require('./config/db');
const { profilesDir } = require('./config/storage');
const uploadRoutes = require('./routes/uploadRoutes');

const app = express();

// Middlewares
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Strictly expose only the profiles directory
app.use('/uploads/profiles', express.static(profilesDir));

// API Routes
app.use('/api/upload', uploadRoutes);

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

const PORT = process.env.PORT || 5010;

/**
 * Async server initialization:
 * Ensures MongoDB connects successfully BEFORE listening for HTTP requests.
 */
const startServer = async () => {
  try {
    // 1. Await database connection first
    await connectDB();

    // 2. Start accepting incoming traffic only after DB is ready
    const server = app.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);
    });

    return server;
  } catch (err) {
    console.error(`FATAL: Server startup aborted due to error: ${err.message}`);
    process.exit(1);
  }
};

// Start server if executed directly
if (require.main === module) {
  startServer();
}

module.exports = { app, startServer };
