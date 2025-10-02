# Dockerfile that mimics Render's deployment process exactly
FROM node:20-alpine

# Set working directory
WORKDIR /app

# Copy package files and prisma schema
COPY package*.json ./
COPY prisma ./prisma

# Install dependencies exactly like Render: npm install --include=dev
RUN npm install --include=dev

# Copy all source code
COPY . .

# Generate Prisma client (part of Render's build process)
RUN npx prisma generate

# Set DATABASE_URL for build process (mimics Render's envVars from database)
# This is needed for Next.js environment validation during build
ARG DATABASE_URL
ENV DATABASE_URL=$DATABASE_URL

# Build the app (using build-ci to skip migrations since we handle them separately)
RUN npm run build-ci

# Expose port
EXPOSE 3000

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# Start exactly like Render: npm run start
CMD ["npm", "run", "start"]