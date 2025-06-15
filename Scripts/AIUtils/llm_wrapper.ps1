param (
    [string[]]$Params
)

# Default values for parameters
$ApiKey = $ENV:GDMS_AI_API_KEY
$ModelID = $ENV:GDMS_AI_MODEL
$AssistantID = "3d0c7941-f101-4dea-bd9a-1d675569cdbb"
$TopP = 0.9
$Temperature = 0.7
$Query = ""

# Parse arguments
foreach ($arg in $Params) {
    if ($arg -like "-ApiKey:*") {
        $ApiKey = $arg.Substring(8)
    } elseif ($arg -like "-ModelID:*") {
        $ModelID = $arg.Substring(9)
    } elseif ($arg -like "-AssistantID:*") {
        $AssistantID = $arg.Substring(13)
    } elseif ($arg -like "-TopP:*") {
        $TopP = [float]$arg.Substring(6)
    } elseif ($arg -like "-Temperature:*") {
        $Temperature = [float]$arg.Substring(13)
    } else {
        $Query += "$arg "
    }
}

$Query = $Query.Trim()

# Call llm.ps1 with the captured parameters
& .\llm.ps1 -ApiKey $ApiKey -ModelID $ModelID -AssistantID $AssistantID -Query $Query -TopP $TopP -Temperature $Temperature
