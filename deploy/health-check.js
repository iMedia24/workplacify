/* eslint-disable */
// Health check endpoint for Cloud Run
// This file can be used to test the health check endpoint

const https = require("https");

const healthCheck = (url) => {
  return new Promise((resolve, reject) => {
    const req = https.get(`${url}/api/trpc/healthcheck`, (res) => {
      let data = "";

      res.on("data", (chunk) => {
        data += chunk;
      });

      res.on("end", () => {
        if (res.statusCode === 200) {
          console.log("✅ Health check passed");
          console.log("Response:", data);
          resolve(data);
        } else {
          console.log("❌ Health check failed");
          console.log("Status:", res.statusCode);
          console.log("Response:", data);
          reject(
            new Error(`Health check failed with status ${res.statusCode}`),
          );
        }
      });
    });

    req.on("error", (error) => {
      console.log("❌ Health check error:", error.message);
      reject(error);
    });

    req.setTimeout(10000, () => {
      req.destroy();
      reject(new Error("Health check timeout"));
    });
  });
};

// Usage: node deploy/health-check.js https://your-app-url.run.app
const url = process.argv[2];
if (!url) {
  console.log(
    "Usage: node deploy/health-check.js https://your-app-url.run.app",
  );
  process.exit(1);
}

healthCheck(url)
  .then(() => {
    console.log("🎉 Application is healthy!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("💥 Health check failed:", error.message);
    process.exit(1);
  });
