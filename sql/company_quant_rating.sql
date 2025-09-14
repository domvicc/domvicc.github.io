-- view name: db.company_quant_rating_vw
-- title: Quant Rating Score (1-10) 

-- reset the old view so we can recreate clean
drop view db.company_overview_ranking_vw
go

-- build the view
create view db.company_overview_ranking_vw as

/* first cleaning raw data to convert types to float */
with base as (  
    select
        sector,                      -- sector label as-is
        industry,                    -- industry label as-is
        symbol,                      -- ticker symbol

        -- core p&l totals (ttm = trailing twelve months)
        try_convert(float, nullif(replace([grossprofitttm],'none',''), '-'))           as gp_ttm,       -- gross profit ttm
        try_convert(float, nullif(replace([revenuettm],'none',''), '-'))               as rev_ttm,      -- revenue ttm
        try_convert(float, nullif(replace([operatingmarginttm],'none',''), '-'))       as op_margin,    -- operating margin ttm (ratio already)
        try_convert(float, nullif(replace([ebitda],'none',''), '-'))                   as ebitda,       -- ebitda absolute

        -- quality ratios (returns)
        try_convert(float, nullif(replace([returnonequityttm],'none',''), '-'))        as roe,          -- return on equity ttm
        try_convert(float, nullif(replace([returnonassetsttm],'none',''), '-'))        as roa,          -- return on assets ttm

        -- growth (year over year)
        try_convert(float, nullif(replace([quarterlyrevenuegrowthyoy],'none',''), '-'))  as rev_g_yoy,  -- revenue yoy growth
        try_convert(float, nullif(replace([quarterlyearningsgrowthyoy],'none',''), '-')) as eps_g_yoy,  -- earnings yoy growth

        -- valuation: pick any sensible pe that shows up first; some feeds bounce around
        coalesce(
            try_convert(float, nullif(replace([peratio],'none',''), '-')),
            try_convert(float, nullif(replace([trailingpe],'-',''), '-')),
            try_convert(float, nullif(replace([forwardpe],'-',''), '-'))
        )                                                                               as pe_any,      -- any pe we can trust

        -- more valuation
        try_convert(float, nullif(replace([pegratio],'none',''), '-'))                  as peg,         -- peg ratio
        try_convert(float, nullif(replace([pricetosalesratiottm],'-',''), '-'))         as ps,          -- price/sales ttm
        try_convert(float, nullif(replace([pricetobookratio],'-',''), '-'))             as pb,          -- price/book
        try_convert(float, nullif(replace([evtorevenue],'-',''), '-'))                  as ev_rev,      -- ev/revenue
        try_convert(float, nullif(replace([evtoebitda],'-',''), '-'))                   as ev_ebitda,   -- ev/ebitda

        -- income stuff
        try_convert(float, nullif(replace([dividendyield],'none',''), '-'))             as div_yield,   -- dividend yield (ratio)
        try_convert(float, nullif(replace([eps],'none',''), '-'))                       as eps,         -- earnings per share
        try_convert(float, nullif(replace([dividendpershare],'none',''), '-'))          as dps,         -- dividend per share

        -- momentum helpers
        try_convert(float, nullif(replace([52weekhigh],'none',''), '-'))                as high_52w,    -- 52w high
        try_convert(float, nullif(replace([52weeklow],'none',''), '-'))                 as low_52w,     -- 52w low
        try_convert(float, nullif(replace([50daymovingaverage],'none',''), '-'))        as dma50,       -- 50d moving avg
        try_convert(float, nullif(replace([200daymovingaverage],'none',''), '-'))       as dma200,      -- 200d moving avg

        -- risk-ish
        try_convert(float, nullif(replace([beta],'-',''), '-'))                         as beta         -- beta (yes, imperfect, still handy)
    from dvic_ticker.db.company_overview_vw
),

/* derived: quick ratios we’ll score
   nothing fancy, just safe math with simple guards */
derived as (
    select
        *,
        case when rev_ttm > 0 then gp_ttm  / rev_ttm end as gross_margin,   -- gross margin %
        case when rev_ttm > 0 then ebitda  / rev_ttm end as ebitda_margin,  -- ebitda margin %
        case when eps is not null and eps > 0 and dps is not null and dps >= 0
             then dps / eps end                              as payout_ratio, -- dividend payout %
        case when high_52w > 0 and low_52w is not null
             then low_52w / high_52w end                     as floor_ratio,  -- where price floor sits vs 52w high
        case when dma200   > 0 and dma50  is not null
             then dma50   / dma200 end                       as trend_ratio   -- quick 50/200 cross vibe
    from base
),

/* scores: turn raw numbers into 1–10 buckets
   nulls sit in the middle so we don’t punish missing data too hard */
scores as (
    select
        sector, industry, symbol,

        /* profitability & quality */
        case when gross_margin is null then 5
             when gross_margin < 0.10 then 1
             when gross_margin < 0.20 then 3
             when gross_margin < 0.30 then 5
             when gross_margin < 0.40 then 7
             when gross_margin < 0.60 then 9
             else 10 end as score_gross_margin,   -- fatter is better

        case when op_margin is null then 5
             when op_margin < 0.00 then 1
             when op_margin < 0.05 then 3
             when op_margin < 0.10 then 5
             when op_margin < 0.15 then 7
             when op_margin < 0.25 then 9
             else 10 end as score_op_margin,      -- steady operators win long-run

        case when ebitda_margin is null then 5
             when ebitda_margin < 0.05 then 1
             when ebitda_margin < 0.10 then 3
             when ebitda_margin < 0.20 then 5
             when ebitda_margin < 0.30 then 7
             when ebitda_margin < 0.45 then 9
             else 10 end as score_ebitda_margin,  -- cash-ish efficiency

        case when roe is null then 5
             when roe <= 0 then 1
             when roe < 0.05 then 3
             when roe < 0.10 then 5
             when roe < 0.20 then 7
             when roe < 0.30 then 9
             else 10 end as score_roe,            -- equity returns

        case when roa is null then 5
             when roa <= 0 then 1
             when roa < 0.01 then 3
             when roa < 0.02 then 5
             when roa < 0.05 then 7
             when roa < 0.10 then 9
             else 10 end as score_roa,            -- asset efficiency

        /* growth */
        case when rev_g_yoy is null then 5
             when rev_g_yoy <= -0.10 then 1
             when rev_g_yoy < 0 then 3
             when rev_g_yoy < 0.10 then 5
             when rev_g_yoy < 0.20 then 7
             when rev_g_yoy < 0.40 then 9
             else 10 end as score_rev_growth,     -- top line accelleration

        case when eps_g_yoy is null then 5
             when eps_g_yoy <= -0.20 then 1
             when eps_g_yoy < 0 then 3
             when eps_g_yoy < 0.10 then 5
             when eps_g_yoy < 0.25 then 7
             when eps_g_yoy < 0.50 then 9
             else 10 end as score_eps_growth,     -- bottom line momentum

        /* valuation */
        case when pe_any is null then 5
             when pe_any <= 0 then 1
             when pe_any < 8 then 8
             when pe_any < 15 then 10
             when pe_any < 25 then 8
             when pe_any < 40 then 6
             when pe_any < 60 then 4
             when pe_any < 100 then 3
             else 1 end as score_pe,              -- classic sweet spot for pe

        case when peg is null then 5
             when peg <= 0 then 1
             when peg < 0.5 then 10
             when peg < 1.0 then 9
             when peg < 1.5 then 7
             when peg < 2.0 then 5
             when peg < 3.0 then 3
             else 1 end as score_peg,             -- growth-adjusted value

        case when ps is null then 5
             when ps < 1 then 10
             when ps < 2 then 8
             when ps < 4 then 6
             when ps < 8 then 3
             else 1 end as score_ps,              -- cheap on sales helps

        case when pb is null then 5
             when pb < 1 then 9
             when pb < 2 then 8
             when pb < 3 then 6
             when pb < 5 then 4
             when pb < 10 then 2
             else 1 end as score_pb,              -- book can be noisy, still ok

        case when ev_rev is null then 5
             when ev_rev < 1 then 10
             when ev_rev < 2 then 8
             when ev_rev < 4 then 6
             when ev_rev < 8 then 3
             else 1 end as score_ev_rev,          -- enterprise value vs sales

        case when ev_ebitda is null then 5
             when ev_ebitda < 6 then 10
             when ev_ebitda < 8 then 9
             when ev_ebitda < 10 then 8
             when ev_ebitda < 12 then 7
             when ev_ebitda < 15 then 5
             when ev_ebitda < 20 then 3
             else 1 end as score_ev_ebitda,       -- classic value metric

        /* income */
        case when div_yield is null then 5
             when div_yield = 0 then 3
             when div_yield < 0.005 then 4
             when div_yield < 0.02 then 6
             when div_yield < 0.04 then 8
             when div_yield < 0.06 then 10
             when div_yield < 0.10 then 5
             else 1 end as score_div_yield,       -- not a huge factor, focus is geared toward aggressive growth, not dividend income

        case when payout_ratio is null then 5
             when eps <= 0 and dps > 0 then 1     -- paying w/out earnings, yikes
             when payout_ratio = 0 then 5
             when payout_ratio < 0.20 then 7
             when payout_ratio < 0.60 then 10     -- comfy zone
             when payout_ratio < 0.80 then 7
             when payout_ratio <= 1.0 then 4
             else 1 end as score_payout_ratio,    -- over 100% is…iffy

        /* momentum */
        case when floor_ratio is null then 5
             when floor_ratio < 0.50 then 2
             when floor_ratio < 0.60 then 4
             when floor_ratio < 0.70 then 6
             when floor_ratio < 0.80 then 8
             when floor_ratio < 0.90 then 9
             else 10 end as score_floor_ratio,    -- closer to the high = stronger

        case when trend_ratio is null then 5
             when trend_ratio < 0.90 then 2
             when trend_ratio < 0.98 then 4
             when trend_ratio <= 1.02 then 6
             when trend_ratio <= 1.05 then 8
             when trend_ratio <= 1.10 then 9
             else 10 end as score_trend_ratio,    -- 50 over 200 = good sign

        /* risk */
        case when beta is null then 5
             when beta between 0 and .10   then 2
             when beta between .10 and .20 then 4
             when beta between .20 and .30 then 6
             when beta between .30 and .40 then 8
             when beta between .40 and .50 then 10
             when beta between .50 and .60 then 10
             when beta between .60 and .70 then 6
             when beta between .70 and .80 then 5
             when beta between .80 and .90 then 4
             when beta between .9 and 1.5  then 2
             when beta > 1.5 then 1
             else 1 end as score_beta              -- calmer beats wild, usually
    from derived
),

/* rollups... pillar avgs and the final blended score
   weights....this part is fairly absract and have been testing with different values q 27.5%, g 20%, v 22.5%, m 15%, i 10%, r 5%  (adds to 100, nice) */
rollups as (
    select
        sector, industry, symbol,

        -- pillar averages (keep exposed for dashboards)
        (score_gross_margin + score_op_margin + score_ebitda_margin + score_roe + score_roa) / 5.0 as [quality],
        (score_rev_growth + score_eps_growth) / 2.0                                                as [growth],
        (score_pe + score_peg + score_ps + score_pb + score_ev_rev + score_ev_ebitda) / 6.0        as [value],
        (score_floor_ratio + score_trend_ratio) / 2.0                                              as [momentum],
        (score_div_yield + score_payout_ratio) / 2.0                                               as [income],
        score_beta                                                                                 as [risk],

        -- final overall 1..10 (rounded just to keep it tidy)
        round(
            /* new weights: q27.5 g20 v22.5 m15 i10 r5 = 100% */
            0.275 * ((score_gross_margin + score_op_margin + score_ebitda_margin + score_roe + score_roa) / 5.0) +
            0.200 * ((score_rev_growth + score_eps_growth) / 2.0) +
            0.225 * ((score_pe + score_peg + score_ps + score_pb + score_ev_rev + score_ev_ebitda) / 6.0) +
            0.150 * ((score_floor_ratio + score_trend_ratio) / 2.0) +
            0.100 * ((score_div_yield + score_payout_ratio) / 2.0) +
            0.050 * score_beta, 
            2
        ) as overall_score_1_to_10
    from scores
)

select *
from rollups
