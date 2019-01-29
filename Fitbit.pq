// This file contains your Data Connector logic
section Fitbit;

client_id = "Client ID Here";
client_secret = "Client Secret Here";
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
windowWidth = 1200;
windowHeight = 1000;

[DataSource.Kind="Fitbit", Publish="Fitbit.Publish"]
shared Fitbit.Navigation = Value.ReplaceType(Navigation, NavigationType);


NavigationType = type function () as table meta [                  
        Documentation.Name = "Fitbit Analytics",
        Documentation.LongDescription = "Returns a table with key Fitbit Data API",
        Documentation.Examples = {[
            Description = "Returns a table with key Fitbit Data API",
            Code = "Fitbit.Navigation () ",
            Result = "A table with key Fitbit Data API"
        ]}
    ];


 Navigation = () =>
    let
        objects = #table(
            {"Name",    "Key",              "Data",             "ItemKind", "ItemName", "IsLeaf"},{
            {"Calories","Fitbit.calories",  Fitbit.calories(),  "Table",    "Table",    true},
            {"Weight",  "Fitbit.Weight",    Fitbit.weight(),    "Table",    "Table",    true},
            {"Food",    "Fitbit.Food",      Fitbit.food(),      "Table",    "Table",    true}     
            }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf") 
    in
        NavTable;

[DataSource.Kind="Fitbit"]
shared Fitbit.calories = () =>
    let
       key = Extension.CurrentCredential()[access_token],
       content = Web.Contents("https://api.fitbit.com/1/user/-/activities/calories/date/2018-01-01/"&Date.ToText(DateTime.Date(DateTime.LocalNow()), "yyyy-MM-dd")&".json",[Headers=[#"Content-type" = "application/json", #"Authorization" = "Bearer " & key]]),
        json=Json.Document(content),
        out = Table.FromRecords(json[#"activities-calories"])
    in
        out;

[DataSource.Kind="Fitbit"]
Fitbit.weight = () =>
    let
       key = Extension.CurrentCredential()[access_token],
       content = Web.Contents("https://api.fitbit.com/1/user/-/body/weight/date/2018-01-01/"&Date.ToText(DateTime.Date(DateTime.LocalNow()), "yyyy-MM-dd")&".json",[Headers=[#"Content-type" = "application/json", #"Authorization" = "Bearer " & key]]),
        json=Json.Document(content),
        out = Table.FromRecords(json[#"body-weight"])
    in
        out;

[DataSource.Kind="Fitbit"]
Fitbit.food = () =>
    let
       key = Extension.CurrentCredential()[access_token],
       content = Web.Contents("https://api.fitbit.com/1/user/-/foods/log/caloriesIn/date/2018-01-01/"&Date.ToText(DateTime.Date(DateTime.LocalNow()), "yyyy-MM-dd")&".json",[Headers=[#"Content-type" = "application/json", #"Authorization" = "Bearer " & key]]),
        json=Json.Document(content),
        out = Table.FromRecords(json[#"foods-log-caloriesIn"])
    in
        out;

// Data Source Kind description//
Fitbit = [
    Authentication = [
             OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,       
            Refresh=Refresh,
            Label = "Fitbit Auth"
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

StartLogin = (resourceUrl, state, display) =>
    let
        AuthorizeUrl = "https://www.fitbit.com/oauth2/authorize?" & Uri.BuildQueryString([
            client_id = client_id,
            state = state,
            response_type = "code",
            scope="activity heartrate location nutrition profile settings sleep social weight",
            redirect_uri = redirect_uri
            ])
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            Context = null
        ];

FinishLogin = (context, callbackUri, state) =>
    let
        parts = Uri.Parts(callbackUri)[Query],
        result = if (Record.HasFields(parts, {"error", "error_description"})) then 
                    error Error.Record(parts[error], parts[error_description], parts)
                 else
                   TokenMethod("authorization_code","code", parts[code])
    in
        result;

Refresh = (resourceUrl, refresh_token) => TokenMethod("refresh_token","refresh_token",  refresh_token);

TokenMethod = (grantType,tokenField, code) =>
    let
         queryString = [
            grant_type = grantType,
            client_id = client_id,                                                
            redirect_uri = redirect_uri
        ],
queryWithCode = if (grantType = "refresh_token") then [ refresh_token = code ] else [code = code], //Record.AddField(queryString, tokenField, code),

         response = Web.Contents("https://api.fitbit.com/oauth2/token", [
            Content = Text.ToBinary(Uri.BuildQueryString(queryString & queryWithCode)),
            Headers=[#"Content-type" = "application/x-www-form-urlencoded",#"Accept" = "application/json",#"Authorization" = "Basic " & Binary.ToText(Text.ToBinary(client_id & ":" & client_secret),0)], ManualStatusHandling = {400}]),
        body = Json.Document(response),
        result = if (Record.HasFields(body, {"error", "error_description"})) then 
                    error Error.Record(body[error], body[error_description], body)
                 else
                    body
    in
        result;

Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;
                
// Data Source UI publishing description
Fitbit.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = Fitbit.Icons,
    SourceTypeImage = Fitbit.Icons
];

Fitbit.Icons = [
    Icon16 = { Extension.Contents("Fitbit16.png"), Extension.Contents("Fitbit20.png"), Extension.Contents("Fitbit24.png"), Extension.Contents("Fitbit32.png") },
    Icon32 = { Extension.Contents("Fitbit32.png"), Extension.Contents("Fitbit40.png"), Extension.Contents("Fitbit48.png"), Extension.Contents("Fitbit64.png") }
];
