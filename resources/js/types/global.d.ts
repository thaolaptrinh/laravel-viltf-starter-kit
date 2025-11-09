import '@inertiajs/core';
import type { UserData } from '@/types/generated/UserData';

// Extend ImportMeta interface for Vite...
declare module 'vite/client' {
    interface ImportMetaEnv {
        readonly VITE_APP_NAME: string;
        [key: string]: string | boolean | undefined;
    }

    interface ImportMeta {
        readonly env: ImportMetaEnv;
        readonly glob: <T>(pattern: string) => Record<string, () => Promise<T>>;
    }
}

declare module '@inertiajs/core' {
    export interface InertiaConfig {
        sharedPageProps: {
            name: string;
            quote: { message: string; author: string };
            auth: { user: UserData };
            sidebarOpen: boolean;
            [key: string]: unknown;
        };
    }
}
