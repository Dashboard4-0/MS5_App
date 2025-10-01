#!/usr/bin/env node

/**
 * MS5.0 Floor Dashboard - Manifest Generator
 * 
 * This script generates the PWA manifest.json file with dynamic values
 * based on the build environment and configuration.
 */

const fs = require('fs');
const path = require('path');

// Configuration
const config = {
  name: 'MS5.0 Floor Dashboard',
  shortName: 'MS5 Dashboard',
  description: 'Factory floor management dashboard optimized for tablet deployment',
  version: process.env.npm_package_version || '1.0.0',
  themeColor: '#1976d2',
  backgroundColor: '#ffffff',
  startUrl: '/',
  display: 'standalone',
  orientation: 'landscape-primary',
  
  // Icon sizes for PWA
  iconSizes: [
    72, 96, 128, 144, 152, 192, 384, 512
  ],
  
  // Screenshot configurations
  screenshots: [
    {
      src: '/screenshots/dashboard-landscape.png',
      sizes: '1024x768',
      type: 'image/png',
      formFactor: 'wide',
      label: 'Dashboard view on tablet'
    },
    {
      src: '/screenshots/andon-landscape.png',
      sizes: '1024x768',
      type: 'image/png',
      formFactor: 'wide',
      label: 'Andon system interface'
    }
  ],
  
  // Shortcuts for quick access
  shortcuts: [
    {
      name: 'Dashboard',
      shortName: 'Dashboard',
      description: 'View production dashboard',
      url: '/dashboard',
      icons: [{ src: '/icons/shortcut-dashboard.png', sizes: '96x96' }]
    },
    {
      name: 'Andon',
      shortName: 'Andon',
      description: 'Access andon system',
      url: '/andon',
      icons: [{ src: '/icons/shortcut-andon.png', sizes: '96x96' }]
    },
    {
      name: 'Jobs',
      shortName: 'Jobs',
      description: 'View job assignments',
      url: '/jobs',
      icons: [{ src: '/icons/shortcut-jobs.png', sizes: '96x96' }]
    }
  ]
};

/**
 * Generate the manifest.json content
 */
function generateManifest() {
  const manifest = {
    name: config.name,
    short_name: config.shortName,
    description: config.description,
    version: config.version,
    start_url: config.startUrl,
    display: config.display,
    orientation: config.orientation,
    theme_color: config.themeColor,
    background_color: config.backgroundColor,
    scope: '/',
    lang: 'en',
    dir: 'ltr',
    categories: ['productivity', 'business', 'utilities'],
    icons: generateIcons(),
    screenshots: config.screenshots,
    shortcuts: config.shortcuts,
    related_applications: [],
    prefer_related_applications: false,
    edge_side_panel: {
      preferred_width: 400
    },
    launch_handler: {
      client_mode: 'navigate-existing'
    },
    protocol_handlers: [
      {
        protocol: 'ms5',
        url: '/?protocol=%s'
      }
    ],
    file_handlers: [
      {
        action: '/upload',
        accept: {
          'application/pdf': ['.pdf'],
          'image/*': ['.jpg', '.jpeg', '.png', '.gif', '.webp'],
          'text/csv': ['.csv'],
          'application/vnd.ms-excel': ['.xls', '.xlsx']
        }
      }
    ],
    share_target: {
      action: '/share',
      method: 'POST',
      enctype: 'multipart/form-data',
      params: {
        title: 'title',
        text: 'text',
        url: 'url',
        files: [
          {
            name: 'file',
            accept: ['image/*', 'application/pdf', 'text/csv']
          }
        ]
      }
    },
    handle_links: 'preferred',
    capture_links: 'new-client',
    offline_enabled: true,
    cache_strategy: 'network-first'
  };

  return manifest;
}

/**
 * Generate icon configurations
 */
function generateIcons() {
  return config.iconSizes.map(size => ({
    src: `/icons/icon-${size}x${size}.png`,
    sizes: `${size}x${size}`,
    type: 'image/png',
    purpose: size >= 192 ? 'any maskable' : 'any'
  }));
}

/**
 * Write manifest to file
 */
function writeManifest() {
  const manifest = generateManifest();
  const outputPath = path.join(__dirname, '../public/manifest.json');
  
  try {
    fs.writeFileSync(outputPath, JSON.stringify(manifest, null, 2));
    console.log('✅ Manifest generated successfully:', outputPath);
    
    // Validate manifest
    validateManifest(manifest);
    
  } catch (error) {
    console.error('❌ Error generating manifest:', error);
    process.exit(1);
  }
}

/**
 * Validate the generated manifest
 */
function validateManifest(manifest) {
  const requiredFields = ['name', 'short_name', 'start_url', 'display', 'icons'];
  const missingFields = requiredFields.filter(field => !manifest[field]);
  
  if (missingFields.length > 0) {
    console.error('❌ Manifest validation failed. Missing required fields:', missingFields);
    process.exit(1);
  }
  
  if (!manifest.icons || manifest.icons.length === 0) {
    console.error('❌ Manifest validation failed. No icons defined.');
    process.exit(1);
  }
  
  // Check for required icon sizes
  const requiredIconSizes = [192, 512];
  const iconSizes = manifest.icons.map(icon => parseInt(icon.sizes.split('x')[0]));
  const missingIconSizes = requiredIconSizes.filter(size => !iconSizes.includes(size));
  
  if (missingIconSizes.length > 0) {
    console.error('❌ Manifest validation failed. Missing required icon sizes:', missingIconSizes);
    process.exit(1);
  }
  
  console.log('✅ Manifest validation passed');
}

/**
 * Generate browserconfig.xml for Windows tiles
 */
function generateBrowserConfig() {
  const browserConfig = {
    browserconfig: {
      'msapplication': {
        tile: {
          'square70x70logo': { src: '/icons/ms-icon-70x70.png' },
          'square150x150logo': { src: '/icons/ms-icon-150x150.png' },
          'square310x310logo': { src: '/icons/ms-icon-310x310.png' },
          'wide310x150logo': { src: '/icons/ms-icon-310x150.png' },
          'TileColor': config.themeColor
        }
      }
    }
  };
  
  const xml = `<?xml version="1.0" encoding="utf-8"?>
<browserconfig>
    <msapplication>
        <tile>
            <square70x70logo src="/icons/ms-icon-70x70.png"/>
            <square150x150logo src="/icons/ms-icon-150x150.png"/>
            <square310x310logo src="/icons/ms-icon-310x310.png"/>
            <wide310x150logo src="/icons/ms-icon-310x150.png"/>
            <TileColor>${config.themeColor}</TileColor>
        </tile>
    </msapplication>
</browserconfig>`;
  
  const outputPath = path.join(__dirname, '../public/browserconfig.xml');
  
  try {
    fs.writeFileSync(outputPath, xml);
    console.log('✅ Browser config generated successfully:', outputPath);
  } catch (error) {
    console.error('❌ Error generating browser config:', error);
    process.exit(1);
  }
}

// Main execution
if (require.main === module) {
  console.log('🚀 Generating PWA manifest...');
  writeManifest();
  generateBrowserConfig();
  console.log('✨ PWA manifest generation complete!');
}

module.exports = {
  generateManifest,
  generateBrowserConfig,
  config
};
