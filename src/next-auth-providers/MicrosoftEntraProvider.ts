import { Provider } from "next-auth/providers/index";

type MicrosoftEntraConfig = {
  clientId: string;
  clientSecret: string;
  issuer: string;
};

export const MicrosoftEntraProvider = (
  config: MicrosoftEntraConfig,
): Provider => {
  // Extract tenant ID from the issuer URL
  const tenantId = config.issuer.match(/\/([^\/]+)\/wsfed$/)?.[1] || "common";

  return {
    id: "microsoft-entra-id",
    name: "Microsoft Entra ID",
    type: "oauth",
    idToken: true,
    client: { token_endpoint_auth_method: "client_secret_post" },
    issuer: `https://login.microsoftonline.com/${tenantId}/v2.0`,
    authorization: {
      url: `https://login.microsoftonline.com/${tenantId}/oauth2/v2.0/authorize`,
      params: { scope: "openid profile email User.Read" },
    },
    wellKnown: `https://login.microsoftonline.com/${tenantId}/v2.0/.well-known/openid-configuration`,
    checks: ["state"],
    token: {
      url: `https://login.microsoftonline.com/${tenantId}/oauth2/v2.0/token`,
    },
    async profile(profile: any, tokens: any) {
      console.log("Microsoft profile data:", profile);

      // Try to get profile photo, but don't let it fail the whole auth process
      let image = null;
      try {
        if (tokens?.access_token) {
          const response = await fetch(
            `https://graph.microsoft.com/v1.0/me/photos/648x648/$value`,
            { headers: { Authorization: `Bearer ${tokens.access_token}` } },
          );

          if (response.ok && typeof Buffer !== "undefined") {
            const pictureBuffer = await response.arrayBuffer();
            const pictureBase64 = Buffer.from(pictureBuffer).toString("base64");
            image = `data:image/jpeg;base64, ${pictureBase64}`;
          }
        }
      } catch (error) {
        console.log("Failed to fetch profile photo:", error);
      }

      const realProfile = {
        id: profile.sub || profile.oid || profile.id,
        name: profile.name || profile.displayName,
        email: profile.email || profile.preferred_username || profile.upn,
        image: image,
      };

      console.log("Mapped profile:", realProfile);
      return realProfile;
    },
    style: {
      text: "#fff",
      bg: "#0072c6",
      logo: "https://learn.microsoft.com/en-us/entra/fundamentals/media/new-name/microsoft-entra-id-icon.png",
    },
    options: config,
  };
};
