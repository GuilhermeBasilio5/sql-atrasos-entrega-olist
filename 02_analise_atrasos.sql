-- =====================================================================
-- Projeto: Atrasos de entrega no e-commerce (base Olist, 2016-2018)
-- Etapa 2: análise
-- Pergunta: onde e quando os atrasos se concentram, e em que etapa?
-- =====================================================================

USE olist;

-- ---------------------------------------------------------------------
-- Visão base: um pedido entregue por linha, já com atraso, nota e
-- tempo de cada etapa. As consultas seguintes partem dela.
-- Atrasado = entregue depois da data prometida ao cliente.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_entregas AS
WITH nota_pedido AS (
    SELECT order_id, AVG(review_score) AS nota
    FROM order_reviews
    GROUP BY order_id
)
SELECT
    o.order_id,
    c.customer_state                                                     AS uf,
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')                     AS mes,
    DATEDIFF(o.order_delivered_customer_date,
             o.order_estimated_delivery_date)                            AS dias_vs_prazo,
    CASE WHEN DATEDIFF(o.order_delivered_customer_date,
                       o.order_estimated_delivery_date) > 0
         THEN 1 ELSE 0 END                                               AS atrasado,
    TIMESTAMPDIFF(HOUR, o.order_approved_at,
                        o.order_delivered_carrier_date) / 24             AS dias_vendedor,
    TIMESTAMPDIFF(HOUR, o.order_delivered_carrier_date,
                        o.order_delivered_customer_date) / 24            AS dias_transporte,
    n.nota
FROM orders o
JOIN customers c        ON c.customer_id = o.customer_id
LEFT JOIN nota_pedido n ON n.order_id    = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_approved_at             IS NOT NULL
  AND o.order_delivered_carrier_date  IS NOT NULL
  AND o.order_delivered_customer_date IS NOT NULL;


-- ---------------------------------------------------------------------
-- 1. Quantos pedidos atrasam?
-- ---------------------------------------------------------------------
SELECT
    COUNT(*)                       AS pedidos,
    SUM(atrasado)                  AS atrasados,
    ROUND(100 * AVG(atrasado), 1)  AS pct_atrasados
FROM vw_entregas;


-- ---------------------------------------------------------------------
-- 2. O atraso afeta a avaliação do cliente?
-- ---------------------------------------------------------------------
SELECT
    CASE atrasado WHEN 1 THEN 'Atrasado' ELSE 'No prazo' END       AS situacao,
    COUNT(*)                                                         AS pedidos,
    ROUND(AVG(nota), 2)                                              AS nota_media,
    ROUND(100 * AVG(CASE WHEN nota <= 2 THEN 1 ELSE 0 END), 1)      AS pct_nota_1_ou_2
FROM vw_entregas
WHERE nota IS NOT NULL
GROUP BY situacao;


-- ---------------------------------------------------------------------
-- 3. Quanto maior o atraso, menor a nota?
-- ---------------------------------------------------------------------
SELECT
    CASE
        WHEN dias_vs_prazo <= 0  THEN '1. No prazo'
        WHEN dias_vs_prazo <= 3  THEN '2. 1 a 3 dias'
        WHEN dias_vs_prazo <= 7  THEN '3. 4 a 7 dias'
        WHEN dias_vs_prazo <= 14 THEN '4. 8 a 14 dias'
        ELSE                          '5. 15 dias ou mais'
    END                  AS faixa_atraso,
    COUNT(*)             AS pedidos,
    ROUND(AVG(nota), 2)  AS nota_media
FROM vw_entregas
WHERE nota IS NOT NULL
GROUP BY faixa_atraso
ORDER BY faixa_atraso;


-- ---------------------------------------------------------------------
-- 4. Quais estados concentram mais atrasos do que pedidos?
-- ---------------------------------------------------------------------
WITH por_uf AS (
    SELECT uf, COUNT(*) AS pedidos, SUM(atrasado) AS atrasados
    FROM vw_entregas
    GROUP BY uf
)
SELECT
    uf,
    pedidos,
    atrasados,
    ROUND(100 * atrasados / pedidos, 1)                 AS taxa_atraso,
    ROUND(100 * pedidos   / SUM(pedidos)   OVER (), 1)  AS pct_dos_pedidos,
    ROUND(100 * atrasados / SUM(atrasados) OVER (), 1)  AS pct_dos_atrasos
FROM por_uf
ORDER BY atrasados DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- 5. O Rio atrasa o ano todo? Taxa de atraso por mês: RJ x MG x SP
-- ---------------------------------------------------------------------
SELECT
    mes,
    ROUND(100 * AVG(CASE WHEN uf = 'RJ' THEN atrasado END), 1)  AS rj,
    ROUND(100 * AVG(CASE WHEN uf = 'MG' THEN atrasado END), 1)  AS mg,
    ROUND(100 * AVG(CASE WHEN uf = 'SP' THEN atrasado END), 1)  AS sp
FROM vw_entregas
WHERE mes BETWEEN '2017-01' AND '2018-08'
GROUP BY mes
ORDER BY mes;


-- ---------------------------------------------------------------------
-- 6. Quanto dos atrasos do Rio vem dos meses de pico?
-- Picos identificados na consulta 5: nov/17, dez/17, fev/18 e mar/18
-- ---------------------------------------------------------------------
WITH rj AS (
    SELECT
        CASE WHEN mes IN ('2017-11', '2017-12', '2018-02', '2018-03')
             THEN 'Pico' ELSE 'Normal' END  AS periodo,
        atrasado,
        nota
    FROM vw_entregas
    WHERE uf = 'RJ'
)
SELECT
    periodo,
    COUNT(*)                                                AS pedidos,
    SUM(atrasado)                                           AS atrasados,
    ROUND(100 * AVG(atrasado), 1)                           AS taxa_atraso,
    ROUND(100 * SUM(atrasado) / SUM(SUM(atrasado)) OVER (), 1) AS pct_dos_atrasos_rj,
    ROUND(AVG(nota), 2)                                     AS nota_media
FROM rj
GROUP BY periodo;


-- ---------------------------------------------------------------------
-- 7. Em que etapa o atraso acontece: vendedor ou transporte?
-- ---------------------------------------------------------------------
SELECT
    CASE WHEN mes IN ('2017-11', '2017-12', '2018-02', '2018-03')
         THEN 'Pico' ELSE 'Normal' END                       AS periodo,
    CASE atrasado WHEN 1 THEN 'Atrasado' ELSE 'No prazo' END AS situacao,
    COUNT(*)                                                 AS pedidos,
    ROUND(AVG(dias_vendedor), 1)                             AS dias_ate_despacho,
    ROUND(AVG(dias_transporte), 1)                           AS dias_de_transporte
FROM vw_entregas
WHERE uf = 'RJ'
GROUP BY periodo, situacao
ORDER BY periodo, situacao;


-- ---------------------------------------------------------------------
-- 8. O Rio atrasou só porque vendeu mais nesses meses?
-- Compara o volume de pedidos do RJ com a taxa de atraso do RJ
-- e com a taxa do resto do país, mês a mês.
-- ---------------------------------------------------------------------
SELECT
    mes,
    SUM(CASE WHEN uf = 'RJ' THEN 1 ELSE 0 END)                 AS pedidos_rj,
    ROUND(100 * AVG(CASE WHEN uf = 'RJ'  THEN atrasado END), 1) AS taxa_rj,
    ROUND(100 * AVG(CASE WHEN uf <> 'RJ' THEN atrasado END), 1) AS taxa_resto_do_pais
FROM vw_entregas
WHERE mes BETWEEN '2017-10' AND '2018-04'
GROUP BY mes
ORDER BY mes;
