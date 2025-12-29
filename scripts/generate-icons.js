#!/usr/bin/env node

/**
 * Script to generate app icons from SVG
 * Requires: sharp (npm install sharp --save-dev)
 * 
 * Run: node scripts/generate-icons.js
 */

const fs = require('fs');
const path = require('path');

// Check if sharp is available
let sharp;
try {
  sharp = require('sharp');
} catch (e) {
  console.error('Error: sharp is not installed. Install it with: npm install sharp --save-dev');
  process.exit(1);
}

const svgPath = path.join(__dirname, '../assets/icons/messenger-icon.svg');
const iconsDir = path.join(__dirname, '../assets/icons');
const trayDir = path.join(__dirname, '../assets/tray');

// Ensure directories exist
[iconsDir, trayDir].forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

// Helper function to generate icon with white background
async function generateIconWithWhiteBackground(svgBuffer, size, outputPath) {
  // Scale icon to 80% of size to add padding (10% margin on each side)
  const iconSize = Math.floor(size * 0.8);
  const padding = Math.floor((size - iconSize) / 2);
  
  // Resize SVG to fit with padding
  const svgResized = await sharp(svgBuffer)
    .resize(iconSize, iconSize)
    .png()
    .toBuffer();
  
  // Create a white background and composite SVG on top with padding
  // Use removeAlpha to ensure no transparency is preserved
  return sharp({
    create: {
      width: size,
      height: size,
      channels: 3, // RGB only, no alpha
      background: { r: 255, g: 255, b: 255 }
    }
  })
    .composite([{ 
      input: svgResized, 
      blend: 'over',
      left: padding,
      top: padding
    }])
    .removeAlpha() // Remove any alpha channel
    .png()
    .toFile(outputPath);
}

async function generateIcons() {
  const svgBuffer = fs.readFileSync(svgPath);
  
  console.log('Generating icons from SVG with white background...');
  
  try {
    // Generate macOS icon (ICNS requires multiple sizes, but we'll create PNG first)
    // For ICNS, you'll need to use iconutil or an online converter
    console.log('Generating PNG icons...');
    
    // Main app icons
    await generateIconWithWhiteBackground(svgBuffer, 512, path.join(iconsDir, 'icon-512.png'));
    
    await generateIconWithWhiteBackground(svgBuffer, 256, path.join(iconsDir, 'icon-256.png'));
    
    await generateIconWithWhiteBackground(svgBuffer, 128, path.join(iconsDir, 'icon-128.png'));
    
    await generateIconWithWhiteBackground(svgBuffer, 64, path.join(iconsDir, 'icon-64.png'));
    
    await generateIconWithWhiteBackground(svgBuffer, 32, path.join(iconsDir, 'icon-32.png'));
    
    await generateIconWithWhiteBackground(svgBuffer, 16, path.join(iconsDir, 'icon-16.png'));
    
    // Use 512px as the main icon.png for Linux
    await generateIconWithWhiteBackground(svgBuffer, 512, path.join(iconsDir, 'icon.png'));
    
    // Generate Windows ICO (multi-size)
    console.log('Generating Windows ICO...');
    await generateIconWithWhiteBackground(svgBuffer, 256, path.join(iconsDir, 'icon.ico'));
    
    // Tray icons (smaller sizes)
    console.log('Generating tray icons...');
    await generateIconWithWhiteBackground(svgBuffer, 22, path.join(trayDir, 'icon.png'));
    
    await generateIconWithWhiteBackground(svgBuffer, 22, path.join(trayDir, 'iconTemplate.png'));
    
    await generateIconWithWhiteBackground(svgBuffer, 32, path.join(trayDir, 'icon.ico'));
    
    // Generate macOS iconset for ICNS
    console.log('Generating macOS iconset...');
    const iconsetDir = path.join(iconsDir, 'icon.iconset');
    if (!fs.existsSync(iconsetDir)) {
      fs.mkdirSync(iconsetDir, { recursive: true });
    }
    
    // macOS iconset requires specific sizes with @2x variants
    const iconsetSizes = [
      { name: 'icon_16x16.png', size: 16 },
      { name: 'icon_16x16@2x.png', size: 32 },
      { name: 'icon_32x32.png', size: 32 },
      { name: 'icon_32x32@2x.png', size: 64 },
      { name: 'icon_128x128.png', size: 128 },
      { name: 'icon_128x128@2x.png', size: 256 },
      { name: 'icon_256x256.png', size: 256 },
      { name: 'icon_256x256@2x.png', size: 512 },
      { name: 'icon_512x512.png', size: 512 },
      { name: 'icon_512x512@2x.png', size: 1024 },
    ];
    
    for (const { name, size } of iconsetSizes) {
      await generateIconWithWhiteBackground(svgBuffer, size, path.join(iconsetDir, name));
    }
    
    // Generate ICNS file using iconutil (macOS only)
    if (process.platform === 'darwin') {
      console.log('Generating ICNS file...');
      const { execSync } = require('child_process');
      try {
        execSync(`iconutil -c icns "${iconsetDir}" -o "${path.join(iconsDir, 'icon.icns')}"`, {
          stdio: 'inherit'
        });
        console.log('✓ ICNS file generated successfully!');
      } catch (error) {
        console.warn('⚠ Could not generate ICNS file. You may need to run manually:');
        console.warn(`  iconutil -c icns "${iconsetDir}" -o "${path.join(iconsDir, 'icon.icns')}"`);
      }
    } else {
      console.log('⚠ ICNS generation skipped (requires macOS). Use an online converter if needed.');
    }
    
    console.log('✓ Icons generated successfully!');
    
  } catch (error) {
    console.error('Error generating icons:', error);
    process.exit(1);
  }
}

generateIcons();

