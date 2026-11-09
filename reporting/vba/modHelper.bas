Attribute VB_Name = "modHelper"
Sub RefreshAll()
    ImportCoefficients
End Sub

Sub ClearCalculator()
    Dim wsCalc As Worksheet
    Set wsCalc = ThisWorkbook.Sheets("Calculator")
    
    wsCalc.Range("B3:B6").ClearContents
    wsCalc.Range("B9:B13").ClearContents
End Sub
