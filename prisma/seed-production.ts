/**
 * Production seed data - minimal setup for production environment
 * This creates only essential data without faker-generated content
 */
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  console.log("🌱 Running production seed...");

  // Check if any organization exists
  const existingOrg = await prisma.organization.findFirst();
  if (existingOrg) {
    console.log("✅ Database already seeded");
    console.log(
      `Organization "${existingOrg.name}" exists with invite code: ${existingOrg.inviteCode}`,
    );
    return;
  }

  // Create a default organization for production
  const organization = await prisma.organization.create({
    data: {
      name: "Your Company",
      description:
        "Welcome to your Workplacify workspace. You can customize this organization in the admin panel.",
    },
  });

  console.log("✅ Production seed completed successfully!");
  console.log(`🏢 Organization created: ${organization.name}`);
  console.log(`🔑 Invite code: ${organization.inviteCode}`);
  console.log("📝 Next steps:");
  console.log("1. Sign in to your application");
  console.log("2. Use the invite code above to join your organization");
  console.log("3. Customize your organization settings");
  console.log("4. Add offices and floors as needed");
}

main()
  .catch((e) => {
    console.error("❌ Production seed failed:", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
