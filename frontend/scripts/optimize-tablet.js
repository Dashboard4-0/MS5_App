#!/usr/bin/env node

/**
 * MS5.0 Floor Dashboard - Tablet Optimization Script
 * 
 * This script optimizes the build for tablet deployment by:
 * - Adjusting touch targets and spacing
 * - Optimizing for landscape orientation
 * - Configuring factory-specific settings
 * - Applying tablet-specific performance optimizations
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Tablet optimization configuration
const tabletConfig = {
  // Touch target minimum sizes (iOS/Android guidelines)
  minTouchTarget: 44, // pixels
  
  // Font size adjustments for tablet
  baseFontSize: 16,
  tabletFontSize: 18,
  
  // Spacing adjustments
  baseSpacing: 8,
  tabletSpacing: 12,
  
  // Performance optimizations
  imageQuality: 85,
  maxImageWidth: 2048,
  maxImageHeight: 1536,
  
  // Factory environment settings
  factorySettings: {
    orientationLock: 'landscape',
    preventSleep: true,
    hapticFeedback: true,
    offlineMode: true,
    autoRefresh: 30000, // 30 seconds
  }
};

/**
 * Optimize CSS for tablet deployment
 */
function optimizeCSS() {
  const cssPath = path.join(__dirname, '../build/static/css');
  
  if (!fs.existsSync(cssPath)) {
    console.log('⚠️  CSS directory not found, skipping CSS optimization');
    return;
  }
  
  const cssFiles = fs.readdirSync(cssPath).filter(file => file.endsWith('.css'));
  
  cssFiles.forEach(file => {
    const filePath = path.join(cssPath, file);
    let css = fs.readFileSync(filePath, 'utf8');
    
    // Add tablet-specific optimizations
    const tabletOptimizations = `
/* Tablet-specific optimizations */
@media screen and (min-width: 768px) {
  /* Increase touch targets */
  button, a, input, select, textarea {
    min-height: ${tabletConfig.minTouchTarget}px;
    min-width: ${tabletConfig.minTouchTarget}px;
  }
  
  /* Optimize font sizes for tablet */
  body {
    font-size: ${tabletConfig.tabletFontSize}px;
    line-height: 1.5;
  }
  
  /* Increase spacing for tablet */
  .container {
    padding: ${tabletConfig.tabletSpacing}px;
  }
  
  /* Landscape orientation optimizations */
  @media screen and (orientation: landscape) {
    body {
      font-size: ${tabletConfig.tabletFontSize + 2}px;
    }
    
    /* Optimize layout for landscape */
    .dashboard-grid {
      grid-template-columns: repeat(4, 1fr);
      gap: ${tabletConfig.tabletSpacing * 2}px;
    }
  }
}

/* Factory environment optimizations */
.factory-environment {
  /* Prevent text selection */
  -webkit-user-select: none;
  -moz-user-select: none;
  -ms-user-select: none;
  user-select: none;
  
  /* Prevent context menu */
  -webkit-touch-callout: none;
  -webkit-tap-highlight-color: transparent;
  
  /* Optimize for touch */
  touch-action: manipulation;
}

/* High contrast mode for factory environments */
@media (prefers-contrast: high) {
  .factory-environment {
    --primary-color: #000000;
    --secondary-color: #ffffff;
    --background-color: #ffffff;
    --text-color: #000000;
  }
}

/* Reduced motion for accessibility */
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
`;
    
    css += tabletOptimizations;
    fs.writeFileSync(filePath, css);
    console.log(`✅ Optimized CSS: ${file}`);
  });
}

/**
 * Optimize images for tablet deployment
 */
function optimizeImages() {
  const imagesPath = path.join(__dirname, '../build/static/images');
  
  if (!fs.existsSync(imagesPath)) {
    console.log('⚠️  Images directory not found, skipping image optimization');
    return;
  }
  
  try {
    // Use ImageMagick or similar tool to optimize images
    const imageFiles = fs.readdirSync(imagesPath).filter(file => 
      /\.(png|jpg|jpeg|gif|webp)$/i.test(file)
    );
    
    imageFiles.forEach(file => {
      const filePath = path.join(imagesPath, file);
      const stats = fs.statSync(filePath);
      
      // Only optimize files larger than 100KB
      if (stats.size > 100 * 1024) {
        try {
          // Resize and optimize image
          execSync(`mogrify -resize ${tabletConfig.maxImageWidth}x${tabletConfig.maxImageHeight}> -quality ${tabletConfig.imageQuality} "${filePath}"`, {
            stdio: 'pipe'
          });
          console.log(`✅ Optimized image: ${file}`);
        } catch (error) {
          console.log(`⚠️  Could not optimize image ${file}: ${error.message}`);
        }
      }
    });
  } catch (error) {
    console.log('⚠️  Image optimization skipped (ImageMagick not available)');
  }
}

/**
 * Generate tablet-specific configuration file
 */
function generateTabletConfig() {
  const config = {
    tablet: {
      enabled: true,
      orientation: tabletConfig.factorySettings.orientationLock,
      touchTargets: {
        minSize: tabletConfig.minTouchTarget,
        spacing: tabletConfig.tabletSpacing
      },
      performance: {
        imageQuality: tabletConfig.imageQuality,
        maxImageWidth: tabletConfig.maxImageWidth,
        maxImageHeight: tabletConfig.maxImageHeight
      },
      factory: tabletConfig.factorySettings
    },
    build: {
      timestamp: new Date().toISOString(),
      version: process.env.npm_package_version || '1.0.0',
      environment: 'tablet-optimized'
    }
  };
  
  const outputPath = path.join(__dirname, '../build/tablet-config.json');
  
  try {
    fs.writeFileSync(outputPath, JSON.stringify(config, null, 2));
    console.log('✅ Generated tablet configuration');
  } catch (error) {
    console.error('❌ Error generating tablet config:', error);
  }
}

/**
 * Update HTML for tablet optimizations
 */
function optimizeHTML() {
  const htmlPath = path.join(__dirname, '../build/index.html');
  
  if (!fs.existsSync(htmlPath)) {
    console.log('⚠️  HTML file not found, skipping HTML optimization');
    return;
  }
  
  let html = fs.readFileSync(htmlPath, 'utf8');
  
  // Add tablet-specific meta tags
  const tabletMetaTags = `
  <!-- Tablet-specific optimizations -->
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, orientation=landscape" />
  <meta name="mobile-web-app-capable" content="yes" />
  <meta name="apple-mobile-web-app-capable" content="yes" />
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
  <meta name="apple-mobile-web-app-title" content="MS5 Dashboard" />
  <meta name="format-detection" content="telephone=no" />
  <meta name="msapplication-tap-highlight" content="no" />
  
  <!-- Factory environment settings -->
  <script>
    window.TABLET_CONFIG = ${JSON.stringify(tabletConfig.factorySettings)};
    window.FACTORY_ENVIRONMENT = true;
  </script>
`;
  
  // Insert meta tags before closing head tag
  html = html.replace('</head>', `${tabletMetaTags}\n</head>`);
  
  // Add tablet-specific CSS class to body
  html = html.replace('<body>', '<body class="tablet-optimized factory-environment">');
  
  fs.writeFileSync(htmlPath, html);
  console.log('✅ Optimized HTML for tablet deployment');
}

/**
 * Validate tablet optimization
 */
function validateOptimization() {
  const buildPath = path.join(__dirname, '../build');
  
  if (!fs.existsSync(buildPath)) {
    console.error('❌ Build directory not found');
    return false;
  }
  
  const requiredFiles = [
    'index.html',
    'tablet-config.json',
    'manifest.json'
  ];
  
  const missingFiles = requiredFiles.filter(file => 
    !fs.existsSync(path.join(buildPath, file))
  );
  
  if (missingFiles.length > 0) {
    console.error('❌ Missing required files:', missingFiles);
    return false;
  }
  
  // Check if CSS files exist
  const cssPath = path.join(buildPath, 'static/css');
  if (!fs.existsSync(cssPath)) {
    console.error('❌ CSS directory not found');
    return false;
  }
  
  console.log('✅ Tablet optimization validation passed');
  return true;
}

/**
 * Main optimization function
 */
function optimizeForTablet() {
  console.log('🚀 Starting tablet optimization...');
  
  try {
    optimizeCSS();
    optimizeImages();
    generateTabletConfig();
    optimizeHTML();
    
    if (validateOptimization()) {
      console.log('✨ Tablet optimization completed successfully!');
    } else {
      console.error('❌ Tablet optimization validation failed');
      process.exit(1);
    }
  } catch (error) {
    console.error('❌ Tablet optimization failed:', error);
    process.exit(1);
  }
}

// Main execution
if (require.main === module) {
  optimizeForTablet();
}

module.exports = {
  optimizeForTablet,
  tabletConfig
};
