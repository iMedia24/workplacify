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

# Set environment variables for build process (mimics Render's envVars)
# This is needed for Next.js environment validation during build
ARG DATABASE_URL
ARG NEXTAUTH_SECRET
ARG NODE_ENV=production

ENV DATABASE_URL=$DATABASE_URL
ENV NEXTAUTH_SECRET=$NEXTAUTH_SECRET
ENV NODE_ENV=$NODE_ENV

# Debug: Echo the DATABASE_URL to see what we're getting
RUN echo "DEBUG: DATABASE_URL length: ${#DATABASE_URL}"
RUN echo "DEBUG: DATABASE_URL value: '$DATABASE_URL'"
RUN echo "DEBUG: DATABASE_URL ends with: '$(echo "$DATABASE_URL" | tail -c 10)'"

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