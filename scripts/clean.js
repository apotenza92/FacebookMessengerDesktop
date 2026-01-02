#!/usr/bin/env node

/**
 * Cross-platform clean script
 * Removes dist and release directories
 */

const fs = require('fs');
const path = require('path');

const rootDir = path.join(__dirname, '..');
const dirsToRemove = ['dist', 'release'];

for (const dir of dirsToRemove) {
  const fullPath = path.join(rootDir, dir);
  if (fs.existsSync(fullPath)) {
    console.log(`Removing ${dir}...`);
    fs.rmSync(fullPath, { recursive: true, force: true });
  }
}

console.log('Clean complete.');

