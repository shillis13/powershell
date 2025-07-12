# SharePoint File Downloader - Complete Activity Flow Diagram

## Main Execution Paths with Intersection Points

```mermaid
graph TD
    A[Script Entry Point] --> B{Sourced?}
    B -->|No| C[mainEntryBlock]
    B -->|Yes| D[Functions Available]
    
    C --> E{URL Provided?}
    E -->|No| F[Setup Mode]
    E -->|Yes| G[Download Mode]
    
    F --> H[Initialize-SharePointSessions]
    G --> I[Get-SharePointFile]
    D --> I
    
    H --> J[Connect-SharePointSession<br/>SP365_DefaultLoginUrl]
    H --> K[Connect-SharePointSession<br/>SP2019_DefaultLoginUrl]
    I --> L[Connect-SharePointSession<br/>User-provided URL]
    
    J --> M[🔄 SHARED SESSION MANAGEMENT]
    K --> M
    L --> M
    
    M --> N[Session Management Tree<br/>See detailed flow below]
```

## **INTERSECTION POINT**: Both Paths Converge at Connect-SharePointSession

### Complete Shared Function Tree (Used by Both Setup and Download Modes)

```mermaid
graph TD
    A[🔄 Connect-SharePointSession<br/>URL parameter] --> B[Get-SharePointSessionInfo<br/>URL]
    B --> C[Resolve-SharePointVersion<br/>URL]
    C --> D{URL Pattern?}
    D -->|*.sharepoint.com| E[Return '365']
    D -->|Other| F[Return '2019']
    
    E --> G[Get script:ChromeDriver_SP365<br/>AuthPort=9222<br/>AuthUrl=SP365_DefaultLoginUrl]
    F --> H[Get script:ChromeDriver_SP2019<br/>AuthPort=9223<br/>AuthUrl=derived from URL]
    
    G --> I[Return SessionInfo<br/>Driver: $script:ChromeDriver_SP365<br/>SpVer: '365'<br/>AuthPort: 9222<br/>AuthUrl: SP365_DefaultLoginUrl<br/>]
    
    H --> J[Return SessionInfo<br/>Driver: $script:ChromeDriver_SP2019<br/>SpVer: '2019'<br/>AuthPort: 9223<br/>AuthUrl: derived URL<br/>]
    
    I --> K[Connect-AuthSession<br/>SessionInfo]
    J --> K
    
    K --> L{SessionInfo.Driver exists?}
    L -->|Yes| M[Test-SessionValidity<br/>Driver, CanaryUrl]
    L -->|No| N[Start-AuthSession<br/>SessionInfo]
    
    M --> O{Session Valid?}
    O -->|Yes| P[Return existing Driver<br/>✅ Reusing session]
    O -->|No| Q[Start-AuthSession<br/>SessionInfo<br/>🔄 Recreating session]
    
    N --> R[Test-ChromeDebugConnection<br/>AuthPort]
    Q --> R
    
    R --> S{Debug Port Available?}
    S -->|Yes| T[Start-SeChrome<br/>ChromeDebuggerAddress<br/>✅ Connected to existing Chrome]
    S -->|No| U[Start-SeChrome<br/>Normal Session<br/>🆕 New Chrome instance]
    
    T --> V[Store Driver in Script Variable]
    U --> W[Enter-SeUrl AuthUrl<br/>Prompt for login]
    W --> V
    
    V --> X{SpVer?}
    X -->|365| Y[script:ChromeDriver_SP365 = Driver]
    X -->|2019| Z[script:ChromeDriver_SP2019 = Driver]
    
    Y --> AA[Return Driver to caller]
    Z --> AA
    P --> AA
```

## Download Mode Continuation (After Session Management)

```mermaid
graph TD
    A[Get-SharePointFile receives Driver<br/>from Connect-SharePointSession] --> B[Request-SharePointFile<br/>Driver, URL]
    
    B --> C[Get-FileNameFromUrl<br/>URL]
    C --> D[Remove-ExistingDownloadFiles<br/>Clear conflicts]
    D --> E[Enter-SeUrl<br/>URL, Driver<br/>🌐 Navigate to file]
    
    E --> F[Wait-ForDownloadCompletion<br/>Monitor download progress]
    F --> G{Download Complete?}
    
    G -->|Yes| H[Get file size<br/>Return DownloadResult<br/>Success=true]
    G -->|No| I[Return DownloadResult<br/>Success=false, Error='Timeout']
    
    H --> J{DestDir specified?}
    I --> K[Get-SharePointFile handles error]
    
    J -->|Yes| L[Move-DownloadedFile<br/>SourcePath, DestinationPath]
    J -->|No| M[Keep in default location]
    
    L --> N[Get-UniqueFilePath<br/>Resolve conflicts]
    N --> O[Move-Item<br/>Physical file move]
    O --> P{Move Success?}
    
    P -->|Yes| Q[Return MoveResult<br/>Success=true, FilePath]
    P -->|No| R[Return MoveResult<br/>Success=false, Error]
    
    M --> S{Open requested?}
    Q --> S
    R --> S
    
    S -->|Yes| T[Open-DownloadedFile<br/>Invoke-Item FilePath]
    S -->|No| U[Final result ready]
    
    T --> U
    U --> V{DoNotPersist?}
    
    V -->|Yes| W[Stop-SeDriver<br/>Close temporary session<br/>🗑️ Clean up]
    V -->|No| X[Keep session for reuse<br/>💾 Persist for future]
    
    W --> Y[Return final result to mainEntryBlock]
    X --> Y
```

## Key Intersection Analysis

### **1. Shared Entry Point: Connect-SharePointSession**

**Setup Mode calls it twice:**
```powershell
# In Initialize-SharePointSessions
Connect-SharePointSession -Url $script:SP365_DefaultLoginUrl
Connect-SharePointSession -Url $script:SP2019_DefaultLoginUrl
```

**Download Mode calls it once:**
```powershell
# In Get-SharePointFile  
Connect-SharePointSession -Url $UserProvidedUrl
```

### **2. Shared Function Tree (Same for All Calls)**

Both modes execute identical logic:
- `Get-SharePointSessionInfo` → URL analysis
- `Resolve-SharePointVersion` → Determine SP365/SP2019
- `Connect-AuthSession` → Session validation/creation
- `Start-AuthSession` → New session creation when needed
- Script variable management → Same storage locations

### **3. Script Variable Intersection**

**Setup Mode populates variables:**
```powershell
# After Initialize-SharePointSessions completes
$script:ChromeDriver_SP365 = WebDriver   # From SP365 setup
$script:ChromeDriver_SP2019 = WebDriver  # From SP2019 setup
```

**Download Mode reuses those variables:**
```powershell
# In Get-SharePointSessionInfo, retrieves:
$existingDriver = $script:ChromeDriver_SP365   # If URL is SP365
$existingDriver = $script:ChromeDriver_SP2019  # If URL is SP2019
```

### **4. Session Lifecycle Shared Behavior**

**Both modes follow same session logic:**
1. **Check existing** → Use `$script:ChromeDriver_*` variables
2. **Validate session** → `Test-SessionValidity` on existing drivers  
3. **Reuse if valid** → Return existing driver without recreation
4. **Recreate if invalid** → Call `Start-AuthSession` with same logic
5. **Store for future** → Update `$script:ChromeDriver_*` variables

## Flow Summary by Mode

### **Setup Mode Flow**
```
mainEntryBlock(URL=null) 
→ Initialize-SharePointSessions 
→ Connect-SharePointSession (×2 calls)
→ [SHARED SESSION MANAGEMENT TREE]
→ Store both SP365 and SP2019 drivers
→ Return setup status
```

### **Download Mode Flow** 
```
mainEntryBlock(URL=provided) 
→ Get-SharePointFile
→ Connect-SharePointSession (×1 call)
→ [SAME SHARED SESSION MANAGEMENT TREE]
→ Reuse existing driver OR create new one
→ Request-SharePointFile + file operations
→ Optional session cleanup
```

## Benefits of This Shared Architecture

1. **Code Reuse**: Session management logic written once, used everywhere
2. **Consistent Behavior**: Same session validation/creation regardless of entry path  
3. **State Persistence**: Setup Mode creates sessions that Download Mode reuses
4. **Efficient Resource Usage**: Avoids duplicate Chrome instances
5. **Transparent Fallback**: Both modes handle missing/invalid sessions identically

The intersection at `Connect-SharePointSession` creates a unified session management system that serves both operational modes while maintaining the script's elegant simplicity.