-- 1. DATA CLEANING & FEATURE ENGINEERING
DROP TABLE IF EXISTS policy_clean;
CREATE TABLE policy_clean AS
SELECT 
    IDpol,
    
    CAST(COALESCE(DrivAge, 45.0) AS REAL) AS DrivAge,
    CAST(COALESCE(VehAge, 5) AS INTEGER) AS VehAge,
    CAST(COALESCE(VehPower, 5) AS INTEGER) AS VehPower,
    VehBrand,
    VehGas,
    CAST(COALESCE(Density, 100.0) AS REAL) AS Density,
    Region,
    Area,
    
    -- 1. If NULL or <= 0, assign a tiny fraction (0.001) so log(offset) doesn't break.
    -- 2. If > 30, it's likely entered in DAYS. Convert to years (divide by 365.25).
    -- 3. Otherwise, trust the value (e.g., 1.5 or 2.0 means a multi-year policy).
    CASE 
        WHEN Exposure IS NULL OR CAST(Exposure AS REAL) <= 0 THEN 0.001
        WHEN CAST(Exposure AS REAL) > 30.0 THEN CAST(Exposure AS REAL) / 365.25
        ELSE CAST(Exposure AS REAL)
    END AS Exposure,
    
    CAST(ClaimNb AS INTEGER) AS ClaimNb

FROM policy_raw;


-- 2. SEVERITY AGGREGATION (Claim Level)
-- A single policy may have multiple claims. We make sure to group it as a total
DROP TABLE IF EXISTS claim_agg;
CREATE TABLE claim_agg AS
SELECT 
    IDpol,
    COUNT(*) AS ClaimCount,
    -- We cap claim amonuts over 10,000 to prevent extreme GLM fitting bias
    CASE
        WHEN SUM(ClaimAmount) > 10000.0 THEN 10000.0
        ELSE SUM(ClaimAmount)
     END AS TotalClaimAmount

FROM claim_raw
WHERE ClaimAmount > 0  
GROUP BY IDpol;


-- 3. FINAL MODELING TABLE
DROP TABLE IF EXISTS modeling_data;
CREATE TABLE modeling_data AS
SELECT 
    p.IDpol,
    p.Exposure,
    p.DrivAge, p.VehAge, p.VehPower, p.VehBrand, p.VehGas, p.Density, p.Region, p.Area,
    
    -- Frequency target 
    p.ClaimNb AS Freq_Count, 
    
    -- Severity targets 
    COALESCE(c.TotalClaimAmount, 0.0) AS Total_Severity,
    COALESCE(c.ClaimCount, 0) AS Sev_ClaimCount,
    
    -- PURE PREMIUM (Total Loss / Exposure)
    (COALESCE(c.TotalClaimAmount, 0.0) / p.Exposure) AS Pure_Premium

FROM policy_clean p
LEFT JOIN claim_agg c ON p.IDpol = c.IDpol;

-- Create an index for performance
CREATE INDEX idx_modeling_idpol ON modeling_data(IDpol);
