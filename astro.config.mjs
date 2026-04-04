// @ts-check

import mdx from '@astrojs/mdx';
import sitemap from '@astrojs/sitemap';
import node from '@astrojs/node';
import { defineConfig } from 'astro/config';

// https://astro.build/config
export default defineConfig({
	site: 'https://signalcircuit.cloud',
	output: 'server',
	adapter: node({ mode: 'standalone' }),
	integrations: [mdx(), sitemap()],
	vite: {
		build: {
			rollupOptions: {
				onwarn(warning, warn) {
					if (
						warning.code === 'UNUSED_EXTERNAL_IMPORT' &&
						String(warning.message).includes('@astrojs/internal-helpers/remote')
					) {
						return;
					}

					warn(warning);
				},
			},
		},
	},
	security: {
		checkOrigin: false,
	},
});
