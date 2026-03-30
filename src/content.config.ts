import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
import { z } from 'astro/zod';

const publication = defineCollection({
  loader: glob({
    base: '/home/administrator/.openclaw/workspace/content/publication/posts',
    pattern: '**/*.md',
  }),
  schema: z.object({
    title: z.string(),
    date: z.coerce.date(),
    category: z.string(),
    tags: z.array(z.string()).default([]),
    excerpt: z.string(),
    author: z.string().default('Publication Staff'),
    image: z.string().optional(),
    sources: z.array(z.string()).default([]),
    type: z.string(),
    draft: z.boolean().default(false),
  }),
});

export const collections = {
  publication,
};
