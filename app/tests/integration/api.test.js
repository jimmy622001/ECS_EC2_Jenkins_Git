const request = require('supertest');
const express = require('express');

// This is a mock test - in a real scenario you'd import the actual app
const app = express();
app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

describe('Health Check API', () => {
  it('GET /health should return 200 OK', async () => {
    const response = await request(app).get('/health');
    expect(response.statusCode).toBe(200);
    expect(response.text).toBe('OK');
  });
});