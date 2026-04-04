#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const repoRoot = '/home/administrator/site';
const authorsTsPath = path.join(repoRoot, 'src/lib/authors.ts');
const authorsDir = path.join(repoRoot, 'public/images/authors');

function parseAuthors(source) {
  const re = /name:\s*'([^']+)'\s*,\s*\n\s*slug:\s*'([^']+)'\s*,\s*\n\s*imagePath:\s*'([^']+)'/g;
  const out = [];
  let m;
  while ((m = re.exec(source)) !== null) {
    out.push({ name: m[1], slug: m[2], imagePath: m[3] });
  }
  return out;
}

function main() {
  const errors = [];
  const warnings = [];

  if (!fs.existsSync(authorsTsPath)) {
    console.error(`ERROR: Missing authors file: ${authorsTsPath}`);
    process.exit(1);
  }

  if (!fs.existsSync(authorsDir)) {
    console.error(`ERROR: Missing authors image dir: ${authorsDir}`);
    process.exit(1);
  }

  const source = fs.readFileSync(authorsTsPath, 'utf8');
  const authors = parseAuthors(source);

  if (authors.length === 0) {
    errors.push('No authors parsed from src/lib/authors.ts');
  }

  const slugSet = new Set();
  const imagePathSet = new Set();

  for (const a of authors) {
    if (slugSet.has(a.slug)) {
      errors.push(`Duplicate slug in authors.ts: ${a.slug}`);
    }
    slugSet.add(a.slug);

    if (imagePathSet.has(a.imagePath)) {
      errors.push(`Duplicate imagePath in authors.ts: ${a.imagePath}`);
    }
    imagePathSet.add(a.imagePath);

    const expectedPath = `/images/authors/${a.slug}.jpg`;
    if (a.imagePath !== expectedPath) {
      warnings.push(`imagePath mismatch for ${a.slug}: expected ${expectedPath}, got ${a.imagePath}`);
    }

    const localPath = path.join(repoRoot, 'public', a.imagePath.replace(/^\//, ''));
    if (!fs.existsSync(localPath)) {
      errors.push(`Missing author image for ${a.slug}: ${localPath}`);
    }
  }

  const files = fs
    .readdirSync(authorsDir)
    .filter((f) => f.toLowerCase().endsWith('.jpg'));

  const expectedFiles = new Set(authors.map((a) => `${a.slug}.jpg`));
  const orphans = files.filter((f) => !expectedFiles.has(f));

  for (const orphan of orphans) {
    warnings.push(`Orphan image not referenced by authors.ts: ${path.join(authorsDir, orphan)}`);
  }

  console.log(`Authors parsed: ${authors.length}`);
  console.log(`Author images found: ${files.length}`);

  if (warnings.length > 0) {
    console.log('\nWarnings:');
    for (const w of warnings) {
      console.log(`- ${w}`);
    }
  }

  if (errors.length > 0) {
    console.log('\nErrors:');
    for (const e of errors) {
      console.log(`- ${e}`);
    }
    process.exit(1);
  }

  console.log('\nAuthor bank validation passed.');
}

main();
