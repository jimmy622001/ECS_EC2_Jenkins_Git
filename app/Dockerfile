FROM node:18-alpine

WORKDIR /app

# Copy package.json and install dependencies
COPY package*.json ./
RUN npm install --production

# Copy application code
COPY . .

# Expose port 8080
EXPOSE 8080

# Command to run the application
CMD ["npm", "start"]