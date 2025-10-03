import { GetServerSideProps } from "next";

const IndexPage = () => {
  // This component will never render due to the redirect
  return null;
};

export const getServerSideProps: GetServerSideProps = async () => {
  return {
    redirect: {
      destination: "/app",
      permanent: false, // Use 302 redirect (temporary) to avoid caching issues
    },
  };
};

export default IndexPage;
