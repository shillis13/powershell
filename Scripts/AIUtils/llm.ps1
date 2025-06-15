# COPYRIGHT 2024 GENERAL DYNAMICS
# To use this script globally you should add the following command
# to your powershell $PROFILE file.
#       Set-Alias llm "C:\Users\user.name\Downloads\llm.ps1"
param (
    [string]$ApiKey = $ENV:GDMS_AI_API_KEY,
    [string]$ModelID = $ENV:GDMS_AI_MODEL,
    # [string]$AssistantID = "default_chatbot",
    [string]$AssistantID = "3d0c7941-f101-4dea-bd9a-1d675569cdbb",
    [string]$Query = "",
    [float]$TopP = 0.9,
    [float]$Temperature = 0.7
)

# Define API key and endpoint
$ApiEndpoint = "https://api.ai.gd-ms.us/v1/assistant/$AssistantID/chat/completions"

if (-not $ModelID) {
    $ModelID = "gpt-4o"
}

# Function to send a message to ChatGPT
function Invoke-LLM () {
    # List of Hashtables that will hold the user message.
    [System.Collections.Generic.List[Hashtable]]$messages = @()

    # Add the user input
    $messages.Add(@{"role"="user"; "content"=$Query})

    # Set the request headers
    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $ApiKey"
    }

    # Set the request body
    $requestBody = @{
        "model" = $ModelID
        "messages" = $messages
        "temperature" = $Temperature
        "top_p" = $TopP
    }

    # Send the request
    $response = Invoke-RestMethod -Method POST -Uri $ApiEndpoint -Headers $headers -Body (ConvertTo-Json $requestBody)

    # Return the message content
    Write-Output $response.choices[0].message.content
}

# If Query is not provided as a parameter, capture it from the command-line arguments
if ($Query -eq "") {
    $Query = $args -join " "
}

# Check if Query is still empty, if so, prompt the user
if ($Query -eq "") {
    $Query = Read-Host "`Provide an input for the assistant"
}

Invoke-LLM
