# osaurus-calendar

An Osaurus plugin for interacting with macOS Calendar.app via AppleScript. Based on [apple-mcp calendar.ts](https://github.com/supermemoryai/apple-mcp/blob/main/utils/calendar.ts).

## Prerequisites

**Automation permissions are required.** Grant permission in:

- System Preferences > Security & Privacy > Privacy > Automation

Add the application using this plugin (e.g., Osaurus, or your terminal if running from CLI) and enable access to **Calendar**.

## Tools

### `get_events`

Get calendar events in a specified date range.

**Parameters:**

- `limit` (optional): Maximum number of events to return (default: 10)
- `fromDate` (optional): Start date in ISO format (default: today)
- `toDate` (optional): End date in ISO format (default: 7 days from now)

**Example:**

```json
{
  "limit": 5,
  "fromDate": "2024-01-15",
  "toDate": "2024-01-22"
}
```

### `search_events`

Search for calendar events that match the search text.

**Parameters:**

- `searchText` (required): Text to search for in event titles
- `limit` (optional): Maximum number of events to return (default: 10)
- `fromDate` (optional): Start date in ISO format (default: today)
- `toDate` (optional): End date in ISO format (default: 30 days from now)

**Example:**

```json
{
  "searchText": "meeting",
  "limit": 10
}
```

### `create_event`

Create a new calendar event.

**Parameters:**

- `title` (required): Title of the event
- `startDate` (required): Start date/time in ISO format (e.g., `2024-01-15T09:00:00Z`)
- `endDate` (required): End date/time in ISO format (e.g., `2024-01-15T10:00:00Z`)
- `location` (optional): Location of the event
- `notes` (optional): Notes/description for the event
- `isAllDay` (optional): Whether this is an all-day event (default: false)
- `calendarName` (optional): Name of the calendar to add the event to (default: first calendar)

**Example:**

```json
{
  "title": "Team Standup",
  "startDate": "2024-01-15T09:00:00Z",
  "endDate": "2024-01-15T09:30:00Z",
  "location": "Conference Room A",
  "notes": "Daily sync meeting"
}
```

### `open_event`

Open a specific calendar event in the Calendar app.

**Parameters:**

- `eventId` (required): ID of the event to open (obtained from `get_events` or `search_events`)

**Example:**

```json
{
  "eventId": "ABC123-DEF456-GHI789"
}
```

## Development

1. Build:

   ```bash
   swift build -c release
   cp .build/release/libosaurus-calendar.dylib ./libosaurus-calendar.dylib
   ```

2. Install locally:
   ```bash
   osaurus tools install .
   ```

## Publishing

### Code Signing (Required for Distribution)

```bash
codesign --force --options runtime --timestamp \
  --sign "Developer ID Application: Your Name (TEAMID)" \
  .build/release/libosaurus-calendar.dylib
```

### Package and Distribute

```bash
osaurus tools package osaurus.calendar 0.1.0
```

This creates `osaurus.calendar-0.1.0.zip` for distribution.

## Response Format

### Event Object

All event-related tools return events in this format:

```json
{
  "id": "unique-event-id",
  "title": "Event Title",
  "location": "Event Location",
  "notes": "Event notes/description",
  "startDate": "2024-01-15 09:00:00",
  "endDate": "2024-01-15 10:00:00",
  "calendarName": "Work",
  "isAllDay": false,
  "url": "https://example.com"
}
```

### Create Event Response

```json
{
  "success": true,
  "message": "Event \"Team Standup\" created successfully.",
  "eventId": "ABC123-DEF456-GHI789"
}
```

## Credits

- [apple-mcp](https://github.com/supermemoryai/apple-mcp) by supermemoryai
