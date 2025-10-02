import { PrismaAdapter } from "@auth/prisma-adapter";
import NextAuth, { AuthOptions } from "next-auth";
import GoogleProvider from "next-auth/providers/google";

import { MicrosoftEntraProvider } from "../../../next-auth-providers/MicrosoftEntraProvider";
import { prisma } from "../../../server/prisma";

const isGoogleAuthProviderConfigured = Boolean(
  typeof process.env.GOOGLE_CLIENT_ID === "string" &&
    typeof process.env.GOOGLE_CLIENT_SECRET === "string",
);

const googleProvider = GoogleProvider({
  clientId: process.env.GOOGLE_CLIENT_ID!,
  clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
});

const isMicrosoftEntraProviderConfigured = Boolean(
  typeof process.env.MICROSOFT_ENTRA_CLIENT_ID === "string" &&
    typeof process.env.MICROSOFT_ENTRA_CLIENT_SECRET === "string" &&
    typeof process.env.MICROSOFT_ENTRA_ISSUER === "string",
);

const microsoftEntraProvider = MicrosoftEntraProvider({
  // Essentials > Application (client) ID
  clientId: process.env.MICROSOFT_ENTRA_CLIENT_ID!,
  // Certificates & secrets > Value
  clientSecret: process.env.MICROSOFT_ENTRA_CLIENT_SECRET!,
  // Endpoints > WS-Federation sign-on endpoint
  issuer: process.env.MICROSOFT_ENTRA_ISSUER!,
});

const baseAdapter = PrismaAdapter(prisma);

// Custom adapter to handle Microsoft's ext_expires_in field
const adapter = {
  ...baseAdapter,
  async linkAccount(account: any) {
    // Transform Microsoft's ext_expires_in to extExpiresIn for Prisma
    if (account.provider === "microsoft-entra-id" && account.ext_expires_in) {
      account.extExpiresIn = account.ext_expires_in;
      delete account.ext_expires_in;
    }
    return baseAdapter.linkAccount!(account);
  },
};

export const nextAuthOptions: AuthOptions = {
  adapter,
  providers: [
    ...(isGoogleAuthProviderConfigured ? [googleProvider] : []),
    ...(isMicrosoftEntraProviderConfigured ? [microsoftEntraProvider] : []),
  ],
  callbacks: {
    session: (props) => {
      return {
        ...props.session,
        user: {
          id: props.user.id,
          ...props.session.user,
        },
      };
    },
  },
};
export default NextAuth(nextAuthOptions);
