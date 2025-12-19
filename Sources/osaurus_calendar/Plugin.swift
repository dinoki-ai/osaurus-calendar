import Cocoa
import Foundation

// MARK: - AppleScript Helper

private enum AppleScriptError: Error {
  case executionFailed(String)
  case noResult
}

private func runAppleScript(_ script: String) -> Result<String, Error> {
  var error: NSDictionary?
  let appleScript = NSAppleScript(source: script)

  guard let result = appleScript?.executeAndReturnError(&error) else {
    if let error = error {
      let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
      return .failure(AppleScriptError.executionFailed(message))
    }
    return .failure(AppleScriptError.noResult)
  }

  return .success(result.stringValue ?? "")
}

// MARK: - Calendar Event Model

private struct CalendarEvent: Codable {
  let id: String
  let title: String
  let location: String?
  let notes: String?
  let startDate: String?
  let endDate: String?
  let calendarName: String
  let isAllDay: Bool
  let url: String?
}

// MARK: - Calendar Tools

private struct GetEventsTool {
  let name = "get_events"

  struct Args: Decodable {
    let limit: Int?
    let fromDate: String?
    let toDate: String?
  }

  func run(args: String) -> String {
    guard let data = args.data(using: .utf8),
      let input = try? JSONDecoder().decode(Args.self, from: data)
    else {
      return "{\"error\": \"Invalid arguments\"}"
    }

    let limit = input.limit ?? 10
    let today = Date()
    let calendar = Calendar.current
    let defaultEndDate = calendar.date(byAdding: .day, value: 7, to: today)!

    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withFullDate]

    let startDateInput = input.fromDate ?? dateFormatter.string(from: today)
    let endDateInput = input.toDate ?? dateFormatter.string(from: defaultEndDate)

    // Parse dates and extract components for AppleScript
    let (startYear, startMonth, startDay) =
      parseDateComponents(startDateInput) ?? getDateComponents(today)
    let (endYear, endMonth, endDay) =
      parseDateComponents(endDateInput) ?? getDateComponents(defaultEndDate)

    let script = """
      tell application "Calendar"
          set eventList to {}
          set eventCount to 0
          set maxEvents to \(limit)
          
          set startDate to current date
          set year of startDate to \(startYear)
          set month of startDate to \(startMonth)
          set day of startDate to \(startDay)
          set hours of startDate to 0
          set minutes of startDate to 0
          set seconds of startDate to 0
          
          set endDate to current date
          set year of endDate to \(endYear)
          set month of endDate to \(endMonth)
          set day of endDate to \(endDay)
          set hours of endDate to 23
          set minutes of endDate to 59
          set seconds of endDate to 59
          
          repeat with cal in calendars
              set calName to name of cal
              set calEvents to (every event of cal whose start date is greater than or equal to startDate and start date is less than or equal to endDate)
              
              repeat with evt in calEvents
                  if eventCount < maxEvents then
                      set evtId to uid of evt
                      set evtTitle to summary of evt
                      if evtTitle is missing value then set evtTitle to ""
                      set evtStart to start date of evt
                      set evtEnd to end date of evt
                      set evtAllDay to allday event of evt
                      
                      set evtLocation to ""
                      try
                          set evtLocation to location of evt
                          if evtLocation is missing value then set evtLocation to ""
                      end try
                      
                      set evtNotes to ""
                      try
                          set evtNotes to description of evt
                          if evtNotes is missing value then set evtNotes to ""
                      end try
                      
                      set evtUrl to ""
                      try
                          set evtUrl to url of evt
                          if evtUrl is missing value then set evtUrl to ""
                      end try
                      
                      set eventInfo to evtId & "|||" & evtTitle & "|||" & calName & "|||" & (evtStart as string) & "|||" & (evtEnd as string) & "|||" & evtAllDay & "|||" & evtLocation & "|||" & evtNotes & "|||" & evtUrl
                      set end of eventList to eventInfo
                      set eventCount to eventCount + 1
                  end if
              end repeat
          end repeat
          
          set AppleScript's text item delimiters to "###"
          return eventList as string
      end tell
      """

    let result = runAppleScript(script)

    switch result {
    case .success(let output):
      let events = parseEvents(output)
      return encodeJSON(events)
    case .failure(let error):
      return "{\"error\": \"\(escapeJSON(error.localizedDescription))\"}"
    }
  }
}

private struct SearchEventsTool {
  let name = "search_events"

  struct Args: Decodable {
    let searchText: String
    let limit: Int?
    let fromDate: String?
    let toDate: String?
  }

  func run(args: String) -> String {
    guard let data = args.data(using: .utf8),
      let input = try? JSONDecoder().decode(Args.self, from: data)
    else {
      return "{\"error\": \"Invalid arguments\"}"
    }

    let limit = input.limit ?? 10
    let today = Date()
    let calendar = Calendar.current
    let defaultEndDate = calendar.date(byAdding: .day, value: 30, to: today)!

    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withFullDate]

    let startDateInput = input.fromDate ?? dateFormatter.string(from: today)
    let endDateInput = input.toDate ?? dateFormatter.string(from: defaultEndDate)
    let searchText = escapeAppleScript(input.searchText.lowercased())

    // Parse dates and extract components for AppleScript
    let (startYear, startMonth, startDay) =
      parseDateComponents(startDateInput) ?? getDateComponents(today)
    let (endYear, endMonth, endDay) =
      parseDateComponents(endDateInput) ?? getDateComponents(defaultEndDate)

    let script = """
      tell application "Calendar"
          set eventList to {}
          set eventCount to 0
          set maxEvents to \(limit)
          set searchTerm to "\(searchText)"
          
          set startDate to current date
          set year of startDate to \(startYear)
          set month of startDate to \(startMonth)
          set day of startDate to \(startDay)
          set hours of startDate to 0
          set minutes of startDate to 0
          set seconds of startDate to 0
          
          set endDate to current date
          set year of endDate to \(endYear)
          set month of endDate to \(endMonth)
          set day of endDate to \(endDay)
          set hours of endDate to 23
          set minutes of endDate to 59
          set seconds of endDate to 59
          
          repeat with cal in calendars
              set calName to name of cal
              set calEvents to (every event of cal whose start date is greater than or equal to startDate and start date is less than or equal to endDate)
              
              repeat with evt in calEvents
                  if eventCount < maxEvents then
                      set evtTitle to summary of evt
                      if evtTitle is missing value then set evtTitle to ""
                      
                      if evtTitle contains searchTerm then
                          set evtId to uid of evt
                          set evtStart to start date of evt
                          set evtEnd to end date of evt
                          set evtAllDay to allday event of evt
                          
                          set evtLocation to ""
                          try
                              set evtLocation to location of evt
                              if evtLocation is missing value then set evtLocation to ""
                          end try
                          
                          set evtNotes to ""
                          try
                              set evtNotes to description of evt
                              if evtNotes is missing value then set evtNotes to ""
                          end try
                          
                          set evtUrl to ""
                          try
                              set evtUrl to url of evt
                              if evtUrl is missing value then set evtUrl to ""
                          end try
                          
                          set eventInfo to evtId & "|||" & evtTitle & "|||" & calName & "|||" & (evtStart as string) & "|||" & (evtEnd as string) & "|||" & evtAllDay & "|||" & evtLocation & "|||" & evtNotes & "|||" & evtUrl
                          set end of eventList to eventInfo
                          set eventCount to eventCount + 1
                      end if
                  end if
              end repeat
          end repeat
          
          set AppleScript's text item delimiters to "###"
          return eventList as string
      end tell
      """

    let result = runAppleScript(script)

    switch result {
    case .success(let output):
      let events = parseEvents(output)
      return encodeJSON(events)
    case .failure(let error):
      return "{\"error\": \"\(escapeJSON(error.localizedDescription))\"}"
    }
  }
}

private struct CreateEventTool {
  let name = "create_event"

  struct Args: Decodable {
    let title: String
    let startDate: String
    let endDate: String
    let location: String?
    let notes: String?
    let isAllDay: Bool?
    let calendarName: String?
  }

  func run(args: String) -> String {
    guard let data = args.data(using: .utf8),
      let input = try? JSONDecoder().decode(Args.self, from: data)
    else {
      return "{\"error\": \"Invalid arguments\"}"
    }

    // Validate inputs
    guard !input.title.trimmingCharacters(in: .whitespaces).isEmpty else {
      return "{\"success\": false, \"message\": \"Event title cannot be empty\"}"
    }

    let dateFormatter = ISO8601DateFormatter()
    guard let startDate = dateFormatter.date(from: input.startDate),
      let endDate = dateFormatter.date(from: input.endDate)
    else {
      return
        "{\"success\": false, \"message\": \"Invalid date format. Please use ISO format (YYYY-MM-DDTHH:mm:ssZ)\"}"
    }

    guard endDate > startDate else {
      return "{\"success\": false, \"message\": \"End date must be after start date\"}"
    }

    let localDateFormatter = DateFormatter()
    localDateFormatter.dateStyle = .full
    localDateFormatter.timeStyle = .short

    let startDateLocal = localDateFormatter.string(from: startDate)
    let endDateLocal = localDateFormatter.string(from: endDate)

    let title = escapeAppleScript(input.title)
    let location = escapeAppleScript(input.location ?? "")
    let notes = escapeAppleScript(input.notes ?? "")
    let isAllDay = input.isAllDay ?? false
    let calendarName = escapeAppleScript(input.calendarName ?? "Calendar")

    let script = """
      tell application "Calendar"
          set startDate to date "\(startDateLocal)"
          set endDate to date "\(endDateLocal)"
          
          set targetCal to null
          try
              set targetCal to calendar "\(calendarName)"
          on error
              set targetCal to first calendar
          end try
          
          tell targetCal
              set newEvent to make new event with properties {summary:"\(title)", start date:startDate, end date:endDate, allday event:\(isAllDay)}
              
              if "\(location)" is not equal to "" then
                  set location of newEvent to "\(location)"
              end if
              
              if "\(notes)" is not equal to "" then
                  set description of newEvent to "\(notes)"
              end if
              
              return uid of newEvent
          end tell
      end tell
      """

    let result = runAppleScript(script)

    switch result {
    case .success(let eventId):
      return
        "{\"success\": true, \"message\": \"Event \\\"\(escapeJSON(input.title))\\\" created successfully.\", \"eventId\": \"\(escapeJSON(eventId))\"}"
    case .failure(let error):
      return "{\"success\": false, \"message\": \"\(escapeJSON(error.localizedDescription))\"}"
    }
  }
}

private struct OpenEventTool {
  let name = "open_event"

  struct Args: Decodable {
    let eventId: String
  }

  func run(args: String) -> String {
    guard let data = args.data(using: .utf8),
      let input = try? JSONDecoder().decode(Args.self, from: data)
    else {
      return "{\"error\": \"Invalid arguments\"}"
    }

    let eventId = escapeAppleScript(input.eventId)

    let script = """
      tell application "Calendar"
          activate
          
          repeat with cal in calendars
              try
                  set evt to (first event of cal whose uid is "\(eventId)")
                  show evt
                  return "Event opened successfully"
              end try
          end repeat
          
          return "Event not found"
      end tell
      """

    let result = runAppleScript(script)

    switch result {
    case .success(let message):
      if message.contains("not found") {
        return "{\"success\": false, \"message\": \"Event not found\"}"
      }
      return "{\"success\": true, \"message\": \"\(escapeJSON(message))\"}"
    case .failure(let error):
      return "{\"success\": false, \"message\": \"\(escapeJSON(error.localizedDescription))\"}"
    }
  }
}

// MARK: - Helper Functions

private func parseDateComponents(_ dateStr: String) -> (Int, Int, Int)? {
  // Parse ISO format date string (YYYY-MM-DD or YYYY-MM-DDTHH:mm:ss...)
  let cleanDate = dateStr.prefix(10)  // Get just the date part
  let parts = cleanDate.split(separator: "-")
  guard parts.count == 3,
    let year = Int(parts[0]),
    let month = Int(parts[1]),
    let day = Int(parts[2])
  else {
    return nil
  }
  return (year, month, day)
}

private func getDateComponents(_ date: Date) -> (Int, Int, Int) {
  let calendar = Calendar.current
  let components = calendar.dateComponents([.year, .month, .day], from: date)
  return (components.year ?? 2024, components.month ?? 1, components.day ?? 1)
}

private func escapeAppleScript(_ str: String) -> String {
  return
    str
    .replacingOccurrences(of: "\\", with: "\\\\")
    .replacingOccurrences(of: "\"", with: "\\\"")
}

private func escapeJSON(_ str: String) -> String {
  return
    str
    .replacingOccurrences(of: "\\", with: "\\\\")
    .replacingOccurrences(of: "\"", with: "\\\"")
    .replacingOccurrences(of: "\n", with: "\\n")
    .replacingOccurrences(of: "\r", with: "\\r")
    .replacingOccurrences(of: "\t", with: "\\t")
}

private func parseEvents(_ output: String) -> [CalendarEvent] {
  guard !output.isEmpty else { return [] }

  let eventStrings = output.components(separatedBy: "###")
  var events: [CalendarEvent] = []

  for eventStr in eventStrings {
    let parts = eventStr.components(separatedBy: "|||")
    guard parts.count >= 6 else { continue }

    let event = CalendarEvent(
      id: parts[0],
      title: parts[1],
      location: parts.count > 6 ? (parts[6].isEmpty ? nil : parts[6]) : nil,
      notes: parts.count > 7 ? (parts[7].isEmpty ? nil : parts[7]) : nil,
      startDate: parts[3],
      endDate: parts[4],
      calendarName: parts[2],
      isAllDay: parts[5] == "true",
      url: parts.count > 8 ? (parts[8].isEmpty ? nil : parts[8]) : nil
    )
    events.append(event)
  }

  return events
}

private func encodeJSON<T: Encodable>(_ value: T) -> String {
  let encoder = JSONEncoder()
  encoder.outputFormatting = .prettyPrinted
  guard let data = try? encoder.encode(value),
    let json = String(data: data, encoding: .utf8)
  else {
    return "[]"
  }
  return json
}

// MARK: - C ABI surface

// Opaque context
private typealias osr_plugin_ctx_t = UnsafeMutableRawPointer

// Function pointers
private typealias osr_free_string_t = @convention(c) (UnsafePointer<CChar>?) -> Void
private typealias osr_init_t = @convention(c) () -> osr_plugin_ctx_t?
private typealias osr_destroy_t = @convention(c) (osr_plugin_ctx_t?) -> Void
private typealias osr_get_manifest_t = @convention(c) (osr_plugin_ctx_t?) -> UnsafePointer<CChar>?
private typealias osr_invoke_t =
  @convention(c) (
    osr_plugin_ctx_t?,
    UnsafePointer<CChar>?,  // type
    UnsafePointer<CChar>?,  // id
    UnsafePointer<CChar>?  // payload
  ) -> UnsafePointer<CChar>?

private struct osr_plugin_api {
  var free_string: osr_free_string_t?
  var `init`: osr_init_t?
  var destroy: osr_destroy_t?
  var get_manifest: osr_get_manifest_t?
  var invoke: osr_invoke_t?
}

// Context state (simple wrapper class to hold state)
private class PluginContext {
  let getEventsTool = GetEventsTool()
  let searchEventsTool = SearchEventsTool()
  let createEventTool = CreateEventTool()
  let openEventTool = OpenEventTool()
}

// Helper to return C strings
private func makeCString(_ s: String) -> UnsafePointer<CChar>? {
  guard let ptr = strdup(s) else { return nil }
  return UnsafePointer(ptr)
}

// API Implementation
private var api: osr_plugin_api = {
  var api = osr_plugin_api()

  api.free_string = { ptr in
    if let p = ptr { free(UnsafeMutableRawPointer(mutating: p)) }
  }

  api.`init` = {
    let ctx = PluginContext()
    return Unmanaged.passRetained(ctx).toOpaque()
  }

  api.destroy = { ctxPtr in
    guard let ctxPtr = ctxPtr else { return }
    Unmanaged<PluginContext>.fromOpaque(ctxPtr).release()
  }

  api.get_manifest = { ctxPtr in
    // Manifest JSON matching new spec
    let manifest = """
      {
        "plugin_id": "osaurus.calendar",
        "version": "0.1.0",
        "description": "A calendar plugin for macOS Calendar.app integration",
        "capabilities": {
          "tools": [
            {
              "id": "get_events",
              "description": "Get calendar events in a specified date range",
              "parameters": {
                "type": "object",
                "properties": {
                  "limit": {
                    "type": "integer",
                    "description": "Maximum number of events to return (default: 10)"
                  },
                  "fromDate": {
                    "type": "string",
                    "description": "Start date for search range in ISO format (default: today)"
                  },
                  "toDate": {
                    "type": "string",
                    "description": "End date for search range in ISO format (default: 7 days from now)"
                  }
                },
                "required": []
              },
              "requirements": [],
              "permission_policy": "auto"
            },
            {
              "id": "search_events",
              "description": "Search for calendar events that match the search text",
              "parameters": {
                "type": "object",
                "properties": {
                  "searchText": {
                    "type": "string",
                    "description": "Text to search for in event titles"
                  },
                  "limit": {
                    "type": "integer",
                    "description": "Maximum number of events to return (default: 10)"
                  },
                  "fromDate": {
                    "type": "string",
                    "description": "Start date for search range in ISO format (default: today)"
                  },
                  "toDate": {
                    "type": "string",
                    "description": "End date for search range in ISO format (default: 30 days from now)"
                  }
                },
                "required": ["searchText"]
              },
              "requirements": [],
              "permission_policy": "auto"
            },
            {
              "id": "create_event",
              "description": "Create a new calendar event",
              "parameters": {
                "type": "object",
                "properties": {
                  "title": {
                    "type": "string",
                    "description": "Title of the event"
                  },
                  "startDate": {
                    "type": "string",
                    "description": "Start date/time in ISO format (e.g., 2024-01-15T09:00:00Z)"
                  },
                  "endDate": {
                    "type": "string",
                    "description": "End date/time in ISO format (e.g., 2024-01-15T10:00:00Z)"
                  },
                  "location": {
                    "type": "string",
                    "description": "Location of the event"
                  },
                  "notes": {
                    "type": "string",
                    "description": "Notes/description for the event"
                  },
                  "isAllDay": {
                    "type": "boolean",
                    "description": "Whether this is an all-day event (default: false)"
                  },
                  "calendarName": {
                    "type": "string",
                    "description": "Name of the calendar to add the event to (default: uses first calendar)"
                  }
                },
                "required": ["title", "startDate", "endDate"]
              },
              "requirements": [],
              "permission_policy": "ask"
            },
            {
              "id": "open_event",
              "description": "Open a specific calendar event in the Calendar app",
              "parameters": {
                "type": "object",
                "properties": {
                  "eventId": {
                    "type": "string",
                    "description": "ID of the event to open"
                  }
                },
                "required": ["eventId"]
              },
              "requirements": [],
              "permission_policy": "auto"
            }
          ]
        }
      }
      """
    return makeCString(manifest)
  }

  api.invoke = { ctxPtr, typePtr, idPtr, payloadPtr in
    guard let ctxPtr = ctxPtr,
      let typePtr = typePtr,
      let idPtr = idPtr,
      let payloadPtr = payloadPtr
    else { return nil }

    let ctx = Unmanaged<PluginContext>.fromOpaque(ctxPtr).takeUnretainedValue()
    let type = String(cString: typePtr)
    let id = String(cString: idPtr)
    let payload = String(cString: payloadPtr)

    guard type == "tool" else {
      return makeCString("{\"error\": \"Unknown capability type\"}")
    }

    switch id {
    case ctx.getEventsTool.name:
      return makeCString(ctx.getEventsTool.run(args: payload))
    case ctx.searchEventsTool.name:
      return makeCString(ctx.searchEventsTool.run(args: payload))
    case ctx.createEventTool.name:
      return makeCString(ctx.createEventTool.run(args: payload))
    case ctx.openEventTool.name:
      return makeCString(ctx.openEventTool.run(args: payload))
    default:
      return makeCString("{\"error\": \"Unknown tool: \(id)\"}")
    }
  }

  return api
}()

@_cdecl("osaurus_plugin_entry")
public func osaurus_plugin_entry() -> UnsafeRawPointer? {
  return UnsafeRawPointer(&api)
}
