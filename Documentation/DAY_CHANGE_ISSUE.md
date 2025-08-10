# Day Change Issue Analysis

## Problem Description
The app doesn't reset "today's cost" when a new day begins. The cost remains showing the previous day's value until the next refresh cycle occurs (default: 30 seconds).

## Root Cause Analysis

### Current Behavior
1. **Data Loading**: Usage data is loaded and cached in memory
2. **Today's Cost Calculation**: 
   - `todaysCostValue` computes today's cost by:
     - Getting current date as "yyyy-MM-dd"
     - Searching for matching entry in `stats.byDate`
     - Returns 0.0 if not found
3. **Refresh Mechanism**: 
   - Auto-refresh every 30 seconds (configurable)
   - Manual refresh on app activation/focus
   - No day change detection

### The Issue
When midnight passes:
- The date formatter produces a new date string (e.g., "2025-08-11" instead of "2025-08-10")
- The cached `stats.byDate` still contains old data
- No entry exists for the new day
- `todaysCostValue` returns 0.0 (which is correct)
- BUT: The UI might still show old values if not properly refreshed

### Why It Appears Not to Reset
1. **Cached Values**: The `todaysCost` string property might be cached
2. **Timing Gap**: Up to 30 seconds delay before auto-refresh
3. **No Day Change Detection**: App doesn't know when midnight passes

## Solution Design

### Approach 1: Day Change Timer (Recommended)
Add a timer that fires at midnight to trigger automatic refresh:
- Calculate time until next midnight
- Schedule timer to fire at 00:00:01
- Refresh data when timer fires
- Reschedule for next day

### Approach 2: Check on Each Access
Check if day has changed whenever `todaysCostValue` is accessed:
- Store last known date
- Compare with current date
- Trigger refresh if different
- Less efficient, more checks

### Approach 3: Frequent Refresh Near Midnight
Increase refresh frequency around midnight:
- Check if within 5 minutes of midnight
- Temporarily increase refresh rate
- Return to normal after midnight
- More complex logic

## Implementation Plan

1. **Add Day Change Detection**:
   - Track the current day
   - Add timer for midnight
   - Trigger refresh on day change

2. **Ensure Proper State Updates**:
   - Clear cached values
   - Force UI refresh
   - Log day change events

3. **Handle Edge Cases**:
   - App suspended during day change
   - Time zone changes
   - System clock adjustments