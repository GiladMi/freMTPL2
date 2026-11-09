Attribute VB_Name = "modImportCoefficients"
Sub ImportCoefficients()
    Dim ws As Worksheet
    Set ws = ThisWorkbook.Sheets("Coefficients")
    
    ' Clear existing data
    ws.Cells.Clear
    
    ' Build file path (CSV is in ../outputs/ relative to the workbook)
    Dim filePath As String
    filePath = ThisWorkbook.Path & "\outputs\coefficients.csv"
    
    If Dir(filePath) = "" Then
        MsgBox "File not found: " & filePath, vbCritical, "Import Error"
        Exit Sub
    End If
    
    ' Import CSV
    With ws.QueryTables.Add("TEXT;" & filePath, ws.Range("A1"))
        .TextFileParseType = xlDelimited
        .TextFileCommaDelimiter = True
        .TextFileColumnDataTypes = Array(2, 2, 2, 2, 1, 1)  ' Text, Text, Text, Text, Number, Number
        .TextFileStartRow = 1
        .Refresh BackgroundQuery:=False
    End With
    
    ' Format headers
    With ws.Range("A1:F1")
        .Font.Bold = True
        .Interior.Color = RGB(200, 220, 240)
    End With
    
    ws.Columns("A:F").AutoFit
    
    MsgBox "Coefficients imported successfully!" & vbCrLf & _
           "Rows: " & ws.Cells(ws.Rows.Count, "A").End(xlUp).Row - 1, _
           vbInformation, "Import Complete"
End Sub

