# Stage 1: Build
FROM node:18-alpine AS builder

# Create app directory
WORKDIR /usr/src/app

# Copy package.json and package-lock.json
COPY package.json ./

# Install app dependencies
RUN npm install

# Copy the rest of the application code
COPY . .

# Stage 2: Production
FROM node:18-alpine

# Create app directory
WORKDIR /usr/src/app

# Copy only the necessary files from the builder stage
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY --from=builder /usr/src/app/package.json ./package.json
COPY --from=builder /usr/src/app/main.js ./main.js

# Expose the port the app runs on
EXPOSE 80

# Command to run the app
CMD ["node", "main.js"]

