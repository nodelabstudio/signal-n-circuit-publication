import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
import { z } from 'astro/zod';

const publication = defineCollection({
  loader: glob({
    base: './src/content/publication',
    pattern: '**/*.md',
  }),
  schema: z.object({
    title: z.string(),
    date: z.coerce.date(),
    category: z.string(),
    tags: z.array(z.string()).default([]),
    excerpt: z.string(),
    author: z.string().default('Publication Staff'),
    authorImage: z.string().default(''),
    authorBio: z.string().default(''),
    image: z.string().optional(),
    sources: z.array(z.string()).default([]),
    type: z.string(),
    draft: z.boolean().default(false),
  }),
});

export const collections = {
  publication,
};
