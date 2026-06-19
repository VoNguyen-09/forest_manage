# PDF Font Issues - Fixed

## Problem
Báo cáo khảo sát PDF (Forest Summary Report) had garbled Vietnamese text/font encoding errors, while other reports (Activity Report, Inventory Report) worked fine.

## Root Cause
The PDF report service was missing **`cellStyle`** parameter in several `TableHelper.fromTextArray()` calls:
- When `cellStyle` is not specified, table cells use the default font instead of the loaded Roboto font
- This caused Vietnamese text to render incorrectly (garbled/mojibake)

## Solution Applied
Added `cellStyle: pw.TextStyle(font: regularFont)` to all `TableHelper.fromTextArray()` calls:

### 1. _buildBreakdownTable (Line ~604)
**Status**: ✅ FIXED
- Added: `cellStyle: pw.TextStyle(font: regularFont, fontSize: 9)`
- Impact: Carbon breakdown table in Forest Summary Report now displays correctly

### 2. Activity Report Main Table (Line ~370) 
**Status**: ✅ FIXED
- Added: `cellStyle: pw.TextStyle(font: regularFont)`
- Impact: Activity log table data cells now use proper font

### 3. Inventory Report Plot Table (Line ~290)
**Status**: ✅ FIXED
- Added: `cellStyle: pw.TextStyle(font: regularFont)`
- Impact: Plot tree data table now uses consistent fonts

### 4. _sectionTitle Helper (Line ~475)
**Status**: ✅ IMPROVED
- Changed: `font: _boldFont` → `font: boldFont` (getter)
- Impact: Consistent font reference handling with fallback support

## Font Loading
All reports now follow the same pattern:
1. Load fonts asynchronously (Roboto via Google Fonts CDN)
2. Set static `_regularFont` and `_boldFont` variables
3. Use getters `regularFont` and `boldFont` which provide Helvetica fallback if CDN fails

## Testing Steps
1. Navigate to Reports screen → Select "Báo cáo Tổng hợp" (Forest Summary)
2. Select a project with carbon data
3. Export PDF → Check that:
   - ✅ Vietnamese text renders correctly (no garbled characters)
   - ✅ Carbon breakdown table displays properly formatted numbers
   - ✅ All tables have proper font styling

## Files Modified
- `lib/features/reports/services/pdf_report_service.dart`

## Verification
- ✅ No compile errors
- ✅ All font specifications present in tables
- ✅ Consistent font handling across all report types
