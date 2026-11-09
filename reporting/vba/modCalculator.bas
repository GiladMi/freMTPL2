Attribute VB_Name = "modCalculator"
Sub CalculatePremium()
    Dim wsCalc As Worksheet, wsCoef As Worksheet
    Set wsCalc = ThisWorkbook.Sheets("Calculator")
    Set wsCoef = ThisWorkbook.Sheets("Coefficients")
    
    ' --- Validate inputs ---
    If wsCalc.Range("B3").value = "" Or _
       wsCalc.Range("B4").value = "" Or _
       wsCalc.Range("B5").value = "" Or _
       wsCalc.Range("B6").value = "" Then
        MsgBox "Please fill in all input fields.", vbExclamation, "Missing Input"
        Exit Sub
    End If
    
    ' --- Read inputs ---
    Dim drivAge As String, vehPower As Double, vehBrand As String, area As String
    drivAge = CStr(wsCalc.Range("B3").value)
    vehPower = CDbl(wsCalc.Range("B4").value)
    vehBrand = CStr(wsCalc.Range("B5").value)
    area = CStr(wsCalc.Range("B6").value)
    
    ' --- Get base rates (Intercept rows) ---
    Dim baseFreq As Double, baseSev As Double, basePP As Double
    baseFreq = LookupRelativitiy(wsCoef, "Frequency", "Intercept", "")
    baseSev = LookupRelativitiy(wsCoef, "Severity", "Intercept", "")
    basePP = LookupRelativitiy(wsCoef, "Tweedie", "Intercept", "")
    
    ' --- Calculate Frequency relativitiy ---
    Dim freqRel As Double
    freqRel = 1#
    freqRel = freqRel * LookupRelativitiy(wsCoef, "Frequency", "DrivAge_Bin", drivAge)
    freqRel = freqRel * GetContinuousRelativitiy(wsCoef, "Frequency", "VehPower", vehPower)
    freqRel = freqRel * LookupRelativitiy(wsCoef, "Frequency", "VehBrand", vehBrand)
    freqRel = freqRel * LookupRelativitiy(wsCoef, "Frequency", "Area", area)
    
    ' --- Calculate Severity relativitiy ---
    Dim sevRel As Double
    sevRel = 1#
    sevRel = sevRel * LookupRelativitiy(wsCoef, "Severity", "DrivAge_Bin", drivAge)
    sevRel = sevRel * GetContinuousRelativitiy(wsCoef, "Severity", "VehPower", vehPower)
    sevRel = sevRel * LookupRelativitiy(wsCoef, "Severity", "VehBrand", vehBrand)
    sevRel = sevRel * LookupRelativitiy(wsCoef, "Severity", "Area", area)
    
    ' --- Calculate Tweedie relativitiy ---
    Dim tweedieRel As Double
    tweedieRel = 1#
    tweedieRel = tweedieRel * LookupRelativitiy(wsCoef, "Tweedie", "DrivAge_Bin", drivAge)
    tweedieRel = tweedieRel * GetContinuousRelativitiy(wsCoef, "Tweedie", "VehPower", vehPower)
    tweedieRel = tweedieRel * LookupRelativitiy(wsCoef, "Tweedie", "VehBrand", vehBrand)
    tweedieRel = tweedieRel * LookupRelativitiy(wsCoef, "Tweedie", "Area", area)
    
    ' --- Calculate predictions ---
    Dim predFreq As Double, predSev As Double, predPP As Double
    predFreq = baseFreq * freqRel
    predSev = baseSev * sevRel
    predPP = basePP * tweedieRel
    
    ' --- Apply 20% loading for expenses/profit ---
    Dim loading As Double, finalPremium As Double
    loading = predPP * 0.2
    finalPremium = predPP + loading
    
    ' --- Display results ---
    wsCalc.Range("B9").value = predFreq
    wsCalc.Range("B10").value = predSev
    wsCalc.Range("B11").value = predPP
    wsCalc.Range("B12").value = loading
    wsCalc.Range("B13").value = finalPremium
    
    ' --- Format output cells ---
    wsCalc.Range("B9").NumberFormat = "0.0000"
    wsCalc.Range("B10:B13").NumberFormat = "€#,##0.00"
    wsCalc.Range("B13").Font.Bold = True
    
    ' --- Optional: Show a summary in a message box ---
    MsgBox "Premium calculated!" & vbCrLf & vbCrLf & _
           "Frequency: " & Format(predFreq, "0.0000") & " claims/year" & vbCrLf & _
           "Severity:  €" & Format(predSev, "#,##0.00") & vbCrLf & _
           "Pure Premium: €" & Format(predPP, "#,##0.00") & vbCrLf & _
           "Final Premium: €" & Format(finalPremium, "#,##0.00"), _
           vbInformation, "Result"
End Sub


' ============================================================
' Helper: Look up a categorical relativitiy
' Columns: A=Model, B=Factor, C=Level, D=Type, E=Relativitiy, F=Coefficient
' Returns 1.0 if not found (i.e., base level)
' ============================================================
Function LookupRelativitiy(ws As Worksheet, modelName As String, _
                           factorName As String, levelName As String) As Double
    Dim lastRow As Long, i As Long
    lastRow = ws.Cells(ws.Rows.Count, "A").End(xlUp).Row
    
    For i = 2 To lastRow
        If ws.Cells(i, 1).value = modelName And _
           ws.Cells(i, 2).value = factorName And _
           ws.Cells(i, 3).value = levelName Then
            LookupRelativitiy = ws.Cells(i, 5).value
            Exit Function
        End If
    Next i
    
    ' Not found = base level, return 1.0
    LookupRelativitiy = 1#
End Function


' ============================================================
' Helper: Compute relativitiy for a continuous variable
' Formula: exp(coefficient * value)
' ============================================================
Function GetContinuousRelativitiy(ws As Worksheet, modelName As String, _
                                  factorName As String, value As Double) As Double
    Dim lastRow As Long, i As Long
    lastRow = ws.Cells(ws.Rows.Count, "A").End(xlUp).Row
    
    For i = 2 To lastRow
        If ws.Cells(i, 1).value = modelName And _
           ws.Cells(i, 2).value = factorName And _
           ws.Cells(i, 4).value = "Continuous" Then
            GetContinuousRelativitiy = Exp(ws.Cells(i, 6).value * value)
            Exit Function
        End If
    Next i
    
    GetContinuousRelativitiy = 1#
End Function

