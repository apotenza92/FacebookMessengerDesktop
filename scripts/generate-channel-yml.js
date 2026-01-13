#!/usr/bin/env node

/**
 * Generates update YML files for both latest and beta channels.
 * Ensures all releases have both channel metadata available for proper auto-update discovery.
 *
 * electron-builder only generates YML for the current version's channel (beta.yml for beta versions,
 * latest.yml for stable versions). This script ensures BOTH channel files exist in every release,
 * allowing the smart update checker to compare versions across channels.
 */

const fs = require('fs');
const path = require('path');

// Read package.json to determine current version
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
const version = pkg.version;
const isBeta = version.includes('beta') || version.includes('alpha') || version.includes('rc');

// Platform-specific YML files to generate
const platforms = [
  { source: 'latest-mac.yml', targets: ['latest-mac.yml', 'beta-mac.yml'] },
  { source: 'latest.yml', targets: ['latest.yml', 'beta.yml'] },
  { source: 'latest-linux.yml', targets: ['latest-linux.yml', 'beta-linux.yml'] },
  { source: 'latest-linux-arm64.yml', targets: ['latest-linux-arm64.yml', 'beta-linux-arm64.yml'] }
];

console.log(`[YML Generator] Version: ${version} (${isBeta ? 'BETA' : 'STABLE'})`);
console.log(`[YML Generator] Ensuring both latest and beta channel files exist...`);

let filesGenerated = 0;
let filesSkipped = 0;

// For each platform, ensure both channel files exist
platforms.forEach(({ source, targets }) => {
  const sourcePath = path.join('release', source);

  if (!fs.existsSync(sourcePath)) {
    console.log(`[YML Generator] ⚠️  ${source} not found, skipping platform`);
    filesSkipped += targets.length;
    return;
  }

  // Read source content
  const sourceContent = fs.readFileSync(sourcePath, 'utf8');

  targets.forEach(target => {
    const targetPath = path.join('release', target);

    // Always write to ensure file exists with current content
    fs.writeFileSync(targetPath, sourceContent, 'utf8');
    console.log(`[YML Generator] ✓ Created: ${target}`);
    filesGenerated++;
  });
});

console.log(`[YML Generator] Complete! Generated ${filesGenerated} files, skipped ${filesSkipped}`);

// Verify critical files exist
const criticalFiles = ['latest.yml', 'beta.yml'];
const missingFiles = criticalFiles.filter(f => !fs.existsSync(path.join('release', f)));

if (missingFiles.length > 0) {
  console.error(`[YML Generator] ❌ ERROR: Critical files missing: ${missingFiles.join(', ')}`);
  process.exit(1);
}

console.log(`[YML Generator] ✓ All critical channel files present`);
