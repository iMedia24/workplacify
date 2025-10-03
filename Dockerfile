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
ARG NEXTAUTH_URL
ARG GOOGLE_CLIENT_ID
ARG GOOGLE_CLIENT_SECRET
ARG CLOUDINARY_API_KEY
ARG CLOUDINARY_API_SECRET
ARG CLOUDINARY_NAME
ARG MICROSOFT_ENTRA_CLIENT_ID
ARG MICROSOFT_ENTRA_CLIENT_SECRET
ARG MICROSOFT_ENTRA_ISSUER
ARG NODE_ENV=production

ENV DATABASE_URL=$DATABASE_URL
ENV NEXTAUTH_SECRET=$NEXTAUTH_SECRET
ENV NEXTAUTH_URL=$NEXTAUTH_URL
ENV GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID
ENV GOOGLE_CLIENT_SECRET=$GOOGLE_CLIENT_SECRET
ENV CLOUDINARY_API_KEY=$CLOUDINARY_API_KEY
ENV CLOUDINARY_API_SECRET=$CLOUDINARY_API_SECRET
ENV CLOUDINARY_NAME=$CLOUDINARY_NAME
ENV MICROSOFT_ENTRA_CLIENT_ID=$MICROSOFT_ENTRA_CLIENT_ID
ENV MICROSOFT_ENTRA_CLIENT_SECRET=$MICROSOFT_ENTRA_CLIENT_SECRET
ENV MICROSOFT_ENTRA_ISSUER=$MICROSOFT_ENTRA_ISSUER
ENV NODE_ENV=$NODE_ENV


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