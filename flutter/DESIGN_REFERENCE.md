# Design Reference

## Color Scheme

### Density Categories

| Category | Label | Color | Weight Range | Use Case |
|----------|-------|-------|--------------|----------|
| 1 | Low Density | Blue (#2196F3) | 0.25 | Minimal density/presence |
| 2 | Medium Density | Yellow (#FBC02D) | 0.50 | Moderate density |
| 3 | High Density | Orange (#FF9800) | 0.75 | High density |
| 4 | Very High Density | Red (#F44336) | 1.00 | Maximum density |

### Heatmap Visualization

- **Circle Radius**: 20 + (weight × 30) pixels
  - Category 1 (0.25): ~27.5px radius
  - Category 2 (0.50): ~35px radius
  - Category 3 (0.75): ~42.5px radius
  - Category 4 (1.00): ~50px radius

- **Opacity**: 0.7 (70%) for all categories
- **Border**: Same color as fill, 30% opacity, 2px stroke

## Theme

### Light Theme
- **Primary Color**: Green (`Colors.green`)
- **Color Scheme**: `ColorScheme.fromSeed(seedColor: Colors.green)`
- **Material Version**: Material Design 3
- **App Bar**: Transparent elevation, centered title

### Dark Theme
- **Primary Color**: Green (`Colors.green`)
- **Color Scheme**: `ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.dark)`
- **Material Version**: Material Design 3
- **Auto Switch**: System preference

## Typography

Using Material Design 3 default typography:
- **Headlines**: For screen titles
- **Body**: For general content
- **Labels**: For buttons and UI elements

## Icons

### Navigation
- Map: `Icons.map` (outlined/filled)
- Capture: `Icons.camera_alt` (outlined/filled)
- My Uploads: `Icons.cloud_upload` (outlined/filled)

### Actions
- Location: `Icons.my_location`
- GPS Fixed: `Icons.gps_fixed`
- GPS Searching: `Icons.gps_not_fixed`
- Login: `Icons.login`
- Logout: `Icons.logout`
- Delete: `Icons.delete`
- Refresh: `Icons.refresh`
- Close: `Icons.close`
- Upload: `Icons.upload`
- Camera: `Icons.camera`

### Status
- Category: `Icons.category`
- Weight: `Icons.scale`
- Location: `Icons.location_on`
- Time: `Icons.access_time`
- ID: `Icons.tag`
- Error: `Icons.error_outline`
- Empty: `Icons.photo_library_outlined`

## Spacing

- **Small**: 8px
- **Medium**: 16px
- **Large**: 24px
- **Extra Large**: 32px, 48px

## Border Radius

- **Small**: 4px (badges, small cards)
- **Medium**: 8px (thumbnails, cards)
- **Large**: 12px (modals)
- **Circular**: 50% (avatars, buttons)

## Elevation/Shadows

Material Design 3 handles elevation automatically:
- **Cards**: Default elevation
- **Floating Action Button**: Default elevation
- **App Bar**: Zero elevation (flat)

## Map Styling

### Base Layer
- **Tile Provider**: OpenStreetMap
- **URL Template**: `https://tile.openstreetmap.org/{z}/{x}/{y}.png`
- **User Agent**: `com.trashmapr.app`

### Default View
- **Initial Zoom**: 13.0
- **Center**: User's current location (fallback: San Francisco 37.7749, -122.4194)

### Markers
- **Size**: 40×40px
- **Border**: 2px white
- **Shadow**: Black 30% opacity, 4px blur
- **Shape**: Circle

### Controls
- **Location Button**: FloatingActionButton.small
- **Legend Card**: Bottom-right, 16px margin
- **Loading Indicator**: Top-center, 16px margin

## Responsive Breakpoints

Mobile-first design:
- **Phone**: < 600dp (primary target)
- **Tablet**: 600-840dp (scales naturally)
- **Desktop**: > 840dp (not optimized, but functional)

## Animation Durations

- **Navigation**: Default (300ms)
- **Debounce**: 500ms (map API calls)
- **Loading**: Indeterminate progress

## Accessibility

- **Minimum Touch Target**: 48×48dp
- **Contrast Ratios**: Material Design 3 defaults
- **Semantic Labels**: Use for screen readers (future enhancement)

## Image Specifications

### Uploaded Photos
- **Format**: JPEG (from camera)
- **Resolution**: Camera default (high)
- **Aspect Ratio**: As captured
- **Loading**: Progressive with placeholder

### Thumbnails
- **Size**: 60×60px (in lists), 40×40px (on map)
- **Fit**: Cover (aspect-fill)
- **Error State**: Grey background with broken image icon

## Loading States

- **Spinner Size**: 16px (inline), 40px (fullscreen)
- **Stroke Width**: 2px (inline), 4px (fullscreen)
- **Color**: Primary color

## Error States

- **Icon Size**: 64px
- **Icon Color**: Red (`Colors.red`)
- **Text**: Centered, medium body text
- **Action Button**: Elevated button with retry action

## Empty States

- **Icon Size**: 80px
- **Icon Color**: Primary color at 30% opacity
- **Text**: Centered, headline + body text
- **Call-to-Action**: Subtle guidance text

## Button Styles

### Primary Action
- **Type**: ElevatedButton
- **Padding**: 24px horizontal, 12px vertical
- **Icon**: 16px, 8px spacing

### Secondary Action
- **Type**: OutlinedButton
- **Padding**: Same as primary
- **Border**: 1px

### Tertiary Action
- **Type**: TextButton
- **Padding**: Minimal
- **Text**: Primary color

### Floating Action
- **Size**: Large (56px) for capture button
- **Size**: Small (40px) for map controls
- **Icon**: 40px (large), 24px (small)

## Modal Dialogs

- **Width**: 90% of screen width (max 400dp)
- **Padding**: 16px
- **Border Radius**: 12px
- **Backdrop**: Black 50% opacity

## App Bar

- **Height**: 56dp (default)
- **Title**: Centered
- **Actions**: 48dp touch targets
- **Elevation**: 0 (flat design)

## Bottom Navigation

- **Height**: 80dp (Material 3 NavigationBar)
- **Items**: 3 (Map, Capture, My Uploads)
- **Labels**: Always visible
- **Icons**: 24dp, outlined/filled based on selection

## Status Indicators

### GPS Status
- **Container**: Card with 8px padding
- **Icon**: 16px (gps_fixed/gps_not_fixed)
- **Text**: 12px monospace for coordinates
- **Colors**: Green (fixed), Orange (searching)

### Upload Status
- **Success**: Green snackbar
- **Error**: Red snackbar
- **Warning**: Orange snackbar
- **Info**: Default snackbar

## Category Badges

- **Padding**: 8px horizontal, 4px vertical
- **Border Radius**: 4px
- **Font Size**: 12px
- **Font Weight**: Bold
- **Text Color**: White
- **Background**: Category color

## Code Color Conventions

```dart
// Primary brand color
const primaryColor = Colors.green;

// Category colors
const category1Color = Colors.blue;
const category2Color = Colors.yellow.shade700;
const category3Color = Colors.orange;
const category4Color = Colors.red;

// Status colors
const successColor = Colors.green;
const errorColor = Colors.red;
const warningColor = Colors.orange;
const infoColor = Colors.blue;

// Neutral colors (Material handles)
// - Background: Theme-based
// - Surface: Theme-based
// - On-Surface: Theme-based
```

---

**Design System**: Material Design 3
**Framework**: Flutter 3+
**Accessibility**: WCAG 2.1 AA (via Material defaults)
