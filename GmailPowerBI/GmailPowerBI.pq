// This file contains your Data Connector logic
section GmailPowerBI;


client_id = "744011364321-679kniskgq81ach4obhpl19239ad6pvr.apps.googleusercontent.com";
client_secret = "l50X4DutQOo4Am8brAwV9bsM";

redirect_uri = "https://preview.powerbi.com/views/oauthredirect.html";

windowWidth = 1200;
windowHeight = 1000;


[DataSource.Kind="GmailPowerBI", Publish="GmailPowerBI.Publish"]


shared GmailPowerBI.NavTableNested = () as table =>
    let

        NavTable = (tb as table) => Table.ToNavigationTable(tb, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf"),
        table_header = {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},

        lv1 = #table(
            table_header,
            {
                {"getListLabels", "getListLabels", GmailPowerBI.getListLabels, "function", "function", "true"},
                {"getListMessages", "getListMessages", GmailPowerBI.getListMessages, "function", "function", "true"},
                {"getMessage", "getMessage", GmailPowerBI.getMessage, "function", "function", "true"}
            }   
        )
    in
        NavTable(lv1);


GmailPowerBI.getListLabels = (userId as text) =>
    let
        endpoint = "https://gmail.googleapis.com/gmail/v1/users/" &userId& "/labels",
        data = Json.Document(Web.Contents(endpoint)),
        table = toTable(data[labels])
    in
        table;


GmailPowerBI.getMessage = (
        userId as text, 
        messagesId as text, 
        optional format as text, 
        optional metadataHeaders as text
        ) =>
    let
        endpoint = "https://gmail.googleapis.com/gmail/v1/users/" &userId& "/messages/" &messagesId,

        addparams =
            let
                a = [],
                b = add_rec(a, "maxResults", format),
                c = add_rec(b, "labelIds", metadataHeaders)
            in
                c,

        data = Json.Document(Web.Contents(endpoint, [Query = addparams])),
        table = toTable(data[labels])
    in
        table;


GmailPowerBI.getListMessages = (
        userId as text, 
        optional labelIds as text, 
        optional query as text,
        optional maxResults as number,
        optional includeSpamTrash as logical,
        optional pagenate_results as logical
        ) =>
    let
        endpoint = "https://gmail.googleapis.com/gmail/v1/users/" &userId& "/messages",

        addparams =
            let
                a = [],
                b = add_rec(a, "maxResults", maxResults),
                c = add_rec(b, "labelIds", labelIds),
                d = add_rec(c, "includeSpamTrash", includeSpamTrash),
                e = add_rec(d, "q", query)
            in
                e,

        data = Json.Document(Web.Contents(endpoint, [Query = addparams]))

    in
        data;

/*
GmailPowerBI.getAttachment = () =>
    let
        endpoint = "https://gmail.googleapis.com/gmail/v1/users/" &user_id& "/messages/" &messageId& "/attachments/" &attach1,

        params = [
            userId=user_id,
            maxResults=Text.From(500),
            labelIds = label
        ],

        data = Json.Document(Web.Contents(endpoint))
    in
        data;
*/

GmailPowerBI = [
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Logout = Logout,
            Refresh = Refresh,
            Label = "Google Gmail Auth"
        ]
    ],
    Label = "Google Gmail Connector"
];


StartLogin = (resourceUrl, state, display) =>
    let
        AuthorizeUrl = "https://accounts.google.com/o/oauth2/v2/auth?" & Uri.BuildQueryString([
            scope = "https://www.googleapis.com/auth/gmail.readonly",
            access_type = "offline",
            include_granted_scopes = "true",
            client_id = client_id,
            state = state,
            redirect_uri = redirect_uri,
            prompt="consent",
            response_type = "code"])
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
        Parts = Uri.Parts(callbackUri)[Query]
    in
        TokenMethod("authorization_code","code" ,Parts[code]);



TokenMethod = (grantType,tokenField,code) =>
    let
        string1=[client_id = client_id,
                client_secret = client_secret,
                grant_type = grantType, 
                redirect_uri = redirect_uri],
        string2=Record.AddField(string1,tokenField,code),
        
        Response = Web.Contents("https://oauth2.googleapis.com/token", [
            Content = Text.ToBinary(Uri.BuildQueryString(string2)),
            Headers=[#"Content-type" = "application/x-www-form-urlencoded", #"Accept" = "application/json"]]),
        Parts = Json.Document(Response)
    in
        Parts;


Refresh = (resourceUrl, refresh_token) => TokenMethod("refresh_token", "refresh_token", refresh_token);

Logout = (token) => "https://accounts.google.com/o/oauth2/revoke?token=" & token;


// Data Source UI publishing description
GmailPowerBI.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = GmailPowerBI.Icons,
    SourceTypeImage = GmailPowerBI.Icons
];

GmailPowerBI.Icons = [
    Icon16 = { Extension.Contents("GmailPowerBI16.png"), Extension.Contents("GmailPowerBI20.png"), Extension.Contents("GmailPowerBI24.png"), Extension.Contents("GmailPowerBI32.png") },
    Icon32 = { Extension.Contents("GmailPowerBI32.png"), Extension.Contents("GmailPowerBI40.png"), Extension.Contents("GmailPowerBI48.png"), Extension.Contents("GmailPowerBI64.png") }
];


add_rec = (rec as record, recname as text, value as any) =>
    if value is null then rec else Record.AddField(rec, recname, value);


toTable = (lstrec as list, optional index as number) as table =>
    let
        fieldnames = 
            let
                toprows = if index is null then lstrec else List.FirstN(lstrec, index),
                listfields = List.Transform(toprows, Record.FieldNames),
                namesdistinct = List.Union(listfields)
            in
                namesdistinct,
        tbl = Table.FromRecords(lstrec, fieldnames, MissingField.UseNull)
    in
        tbl;


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
