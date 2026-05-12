-- Session engagement and purchase correlation analysis
-- Dataset: Google Analytics 4 Ecommerce Sample
-- Tools: SQL, BigQuery

WITH base AS (
  SELECT
    user_pseudo_id,
    (
      SELECT value.int_value
      FROM UNNEST(event_params)
      WHERE key = 'ga_session_id'
    ) AS session_id,
    event_name,
    (
      SELECT value.string_value
      FROM UNNEST(event_params)
      WHERE key = 'page_location'
    ) AS page_location
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX LIKE '2020%'
),

landing_sessions AS (
  SELECT
    CONCAT(user_pseudo_id, '-', CAST(session_id AS STRING)) AS session_key,
    REGEXP_REPLACE(
      REGEXP_REPLACE(page_location, r'^https?://[^/]+', ''),
      r'\?.*$',
      ''
    ) AS page_path
  FROM base
  WHERE event_name = 'session_start'
    AND session_id IS NOT NULL
    AND page_location IS NOT NULL
),

purchases AS (
  SELECT DISTINCT
    CONCAT(user_pseudo_id, '-', CAST(session_id AS STRING)) AS session_key
  FROM base
  WHERE event_name = 'purchase'
    AND session_id IS NOT NULL
)

SELECT
  page_path,
  COUNT(DISTINCT landing_sessions.session_key) AS sessions_count,
  COUNT(DISTINCT purchases.session_key) AS purchases_count,
  SAFE_DIVIDE(
    COUNT(DISTINCT purchases.session_key),
    COUNT(DISTINCT landing_sessions.session_key)
  ) AS session_to_purchase_conversion_rate
FROM landing_sessions
LEFT JOIN purchases
  ON landing_sessions.session_key = purchases.session_key
GROUP BY page_path
ORDER BY session_to_purchase_conversion_rate DESC, sessions_count DESC
