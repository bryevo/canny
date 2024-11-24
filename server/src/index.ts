import express from 'express';

import bodyParser from 'body-parser';
import cors from 'cors';
import routes from './routes';

// Initialize Express app
const app = express();

// Middleware
app.use(express.json());
app.use(cors());
app.use(bodyParser.json());

// Routes
app.use('/api', routes);

export const SECRET_KEY = 'canny-secret-key';

// Start server
const port = 3000;
app.listen(port, () => {
  console.log(`Server started on port ${port}`);
});
