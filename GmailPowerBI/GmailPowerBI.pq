// This file contains your Data Connector logic
section GmailPowerBI;


client_id = "744011364321-679kniskgq81ach4obhpl19239ad6pvr.apps.googleusercontent.com";
client_secret = "l50X4DutQOo4Am8brAwV9bsM";

redirect_uri = "https://preview.powerbi.com/views/oauthredirect.html";

windowWidth = 1200;
windowHeight = 1000;


formatOptions = [
    #"full" = "full",
    #"full (include binary Attachments)" = "full",
    #"raw" = "raw",
    #"minimal" = "minimal",
    #"metadata" = "metadata",
    #"only Ids" = null
];

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
                {"getMessage", "getMessage", GmailPowerBI.getMessage, "function", "function", "true"},
                {"getAttachment", "getAttachment", GmailPowerBI.getAttachment, "function", "function", "true"},
                {"Base64Url.Decode", "Base64Url.Decode", Base64Url.Decode, "function", "function", "true"}
            }   
        )
    in
        NavTable(lv1);


//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//Documentation func
/*
userId as text, 
optional labelIds as text, 
optional query as text,
optional maxResults as number,
optional includeSpamTrash as logical,
optional messageFormat as text,
optional metadataHeaders as text,
optional pagenateResults as logical
*/


GmailPowerBI.getListMessages = Value.ReplaceType(GmailPowerBI.getListMessagesImpl, GmailPowerBI.getListMessagesType);
GmailPowerBI.getListMessagesType =
type function (  
                     userId as (type text meta [
                        Documentation.FieldCaption = "Gmail account",
                        Documentation.FieldDescription = "The user's email address. The special value me can be used to indicate the authenticated user.",
                        Documentation.SampleValues = {"romanshapkov@gmail.com"}
                        ]),
                     optional labelIds as (type text meta [
                        Documentation.FieldCaption = "label IDs",
                        Documentation.FieldDescription = "Only return messages with labels that match all of the specified label IDs",
                        Documentation.SampleValues = {"INBOX", "CHAT", "SPAM", "Label_61045850528162158"}
                     ]),
                     optional query as (type text meta [
                        Documentation.FieldCaption = "Gmail search box",
                        Documentation.FieldDescription = "Only return messages matching the specified query.#(cr)#(lf)Supports the same query format as the Gmail search box.#(cr)#(lf)For example, 'from:someuser@example.com rfc822msgid:<somemsgid@example.com> is:unread'.#(cr)#(lf) Parameter cannot be used when accessing the api using the gmail.metadata scope.",
                        Documentation.SampleValues = {"from:(support@prog4.ru) after:2021/8/1 before:2021/9/2 subject:reports_flow ","from:(support@prog4.ru) to:(romanshapkov@gmail.com) subject:reports_flow after:2021/8/29 before:2021/9/5","from:(support@prog4.ru) after:2021/8/1 before:2021/9/2", "from:someuser@example.com rfc822msgid:<somemsgid@example.com> is:unread"},
                        Formatting.IsMultiLine = true,
                        Formatting.IsCode = true
                     ]),
                     optional maxResults as (type text meta [
                        Documentation.FieldCaption = "Maximum number of messages",
                        Documentation.FieldDescription = "Maximum number of messages to return. This field defaults to 100. The maximum allowed value for this field is 500.",
                        Documentation.SampleValues = {"500"}
                     ]),
                     optional includeSpamTrash as (type logical meta [
                        Documentation.FieldCaption = "Include messages from SPAM and TRASH in the results.",
                        Documentation.FieldDescription = "Include messages from SPAM and TRASH in the results.",
                        Documentation.SampleValues = {"True", "False"},
                        Documentation.AllowedValues = {true, false}
                     ]),
                     optional messageFormat as (type text meta [
                        Documentation.FieldCaption = "The format to return the message in.",
                        Documentation.FieldDescription = "The format to return the message in.",
                        Documentation.SampleValues = Record.FieldNames(formatOptions),
                        Documentation.AllowedValues = Record.FieldNames(formatOptions)
                     ]),
                     optional metadataHeaders as (type text meta [
                        Documentation.FieldCaption = "When given and format is METADATA, only include headers specified.",
                        Documentation.FieldDescription = "When given and format is METADATA, only include headers specified."
                     ]),
                     optional pagenateResults as (type logical meta [
                        Documentation.FieldCaption = "Activate pagination results.",
                        Documentation.FieldDescription = "Activate pagination results.",
                        Documentation.SampleValues = {"True", "False"},
                        Documentation.AllowedValues = {true, false}
                     ])
                   )
        as function meta [
            Documentation.Name = "getListMessages",
            Documentation.LongDescription = "Gets the specified messages. Include binary attachment"
    ];


//////////////////////////////////////////////////////////////////////////////////////////////////////////////

GmailPowerBI.getListLabels = (userId as text) =>
    let
        endpoint = "https://gmail.googleapis.com/gmail/v1/users/" &userId& "/labels",
        data = Json.Document(Web.Contents(endpoint)),
        table = toTable(data[labels])
    in
        table;


GmailPowerBI.getMessage = (
        userId as text, 
        messageId as text, 
        optional format as text, 
        optional metadataHeaders as text
        ) =>
    let
        endpoint = "https://gmail.googleapis.com/gmail/v1/users/" &userId& "/messages/" &messageId,
        messageFormat = Record.FieldOrDefault(formatOptions, format, "full"),
        addparams =
            let
                a = [],
                b = add_rec(a, "format", messageFormat),
                c = add_rec(b, "metadataHeaders", metadataHeaders)
            in
                c,
        message = Json.Document(Web.Contents(endpoint, [Query = addparams])),
        Attach =
            let
                parts = message[payload][parts],
                partsWithAttach = List.Select(parts, each Record.HasFields(_[body], "attachmentId") ),
                getAllattach = 
                    List.Transform(partsWithAttach, each 
                       Record.AddField(_, "base64UrlContent",   
                         GmailPowerBI.getAttachment( userId, messageId, _[body][attachmentId]) 
                        )) 
            in
               getAllattach,
        combineRecord = if format = "full (include binary Attachments)" then Record.AddField(message, "Attacments", Attach) else message 
    in
        combineRecord;


GmailPowerBI.getAttachment = (
        userId as text, 
        messageId as text,
        attachmentId as text
        ) =>
    let
        endpoint = "https://gmail.googleapis.com/gmail/v1/users/" &userId& "/messages/" &messageId& "/attachments/" & attachmentId,
        attach = Json.Document(Web.Contents(endpoint))
    in 
        attach;

GmailPowerBI.getListMessagesImpl = (
        userId as text, 
        optional labelIds as text, 
        optional query as text,
        optional maxResults as number,
        optional includeSpamTrash as logical,
        optional messageFormat as text,
        optional metadataHeaders as text,
        optional pagenateResults as logical
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
        data = Json.Document(Web.Contents(endpoint, [Query = addparams])),


        messages = 
            let
                messageList = data[messages],
                messageDetails = List.Transform( messageList, each GmailPowerBI.getMessage(userId, _[id], messageFormat, metadataHeaders)),
                rows = if messageFormat is null then messageList else messageDetails
            in
                toTable(rows)
    in
        messages;


GmailPowerBI = [
    TestConnection = (dataSourcePath) => {"GmailPowerBI.NavTableNested"},
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

//Curth 
//https://community.powerbi.com/t5/Power-Query/Decode-JWT-token-in-custom-connector/m-p/1643221
Base64Url.Decode = (s) => 
    Binary.FromText(
        Text.Replace( Text.Replace(s, "-", "+"), "_", "/") 
        & 
        {"", "", "==", "="}{Number.Mod(Text.Length(s), 4)}
    , BinaryEncoding.Base64);
