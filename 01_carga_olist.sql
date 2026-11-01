-- =====================================================================
-- Projeto: Atrasos de entrega no e-commerce (base Olist)
-- Etapa 1: criar o banco e carregar as tabelas
-- Fonte dos dados: Brazilian E-Commerce Public Dataset by Olist (Kaggle)
-- =====================================================================

-- Os CSVs precisam estar na pasta liberada pelo MySQL.
-- Confira qual é ela com o comando abaixo (normalmente
-- C:\ProgramData\MySQL\MySQL Server 8.0\Uploads\):
SHOW VARIABLES LIKE 'secure_file_priv';

CREATE DATABASE IF NOT EXISTS olist CHARACTER SET utf8mb4;
USE olist;

DROP TABLE IF EXISTS order_reviews, order_items, orders, customers, sellers;

-- ---------------------------------------------------------------------
-- Clientes
-- ---------------------------------------------------------------------
CREATE TABLE customers (
    customer_id              CHAR(32) PRIMARY KEY,
    customer_unique_id       CHAR(32),
    customer_zip_code_prefix VARCHAR(5),
    customer_city            VARCHAR(60),
    customer_state           CHAR(2)
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_customers_dataset.csv'
INTO TABLE customers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- ---------------------------------------------------------------------
-- Vendedores
-- ---------------------------------------------------------------------
CREATE TABLE sellers (
    seller_id              CHAR(32) PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(5),
    seller_city            VARCHAR(60),
    seller_state           CHAR(2)
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_sellers_dataset.csv'
INTO TABLE sellers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- ---------------------------------------------------------------------
-- Pedidos (datas vazias viram NULL)
-- ---------------------------------------------------------------------
CREATE TABLE orders (
    order_id                      CHAR(32) PRIMARY KEY,
    customer_id                   CHAR(32),
    order_status                  VARCHAR(20),
    order_purchase_timestamp      DATETIME,
    order_approved_at             DATETIME,
    order_delivered_carrier_date  DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATETIME
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_orders_dataset.csv'
INTO TABLE orders
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, customer_id, order_status, @compra, @aprovado, @transportadora, @entregue, @previsto)
SET order_purchase_timestamp      = NULLIF(@compra, ''),
    order_approved_at             = NULLIF(@aprovado, ''),
    order_delivered_carrier_date  = NULLIF(@transportadora, ''),
    order_delivered_customer_date = NULLIF(@entregue, ''),
    order_estimated_delivery_date = NULLIF(@previsto, '');

-- ---------------------------------------------------------------------
-- Itens do pedido
-- ---------------------------------------------------------------------
CREATE TABLE order_items (
    order_id            CHAR(32),
    order_item_id       INT,
    product_id          CHAR(32),
    seller_id           CHAR(32),
    shipping_limit_date DATETIME,
    price               DECIMAL(10,2),
    freight_value       DECIMAL(10,2),
    PRIMARY KEY (order_id, order_item_id)
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_order_items_dataset.csv'
INTO TABLE order_items
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- ---------------------------------------------------------------------
-- Avaliações (este arquivo usa quebra de linha do Windows: \r\n)
-- Os comentários escritos pelos clientes não são carregados:
-- a análise usa só a nota.
-- ---------------------------------------------------------------------
CREATE TABLE order_reviews (
    review_id            CHAR(32),
    order_id             CHAR(32),
    review_score         TINYINT,
    review_creation_date DATETIME
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_order_reviews_dataset.csv'
INTO TABLE order_reviews
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(review_id, order_id, review_score, @titulo, @comentario, @criada, @respondida)
SET review_creation_date = NULLIF(@criada, '');

-- ---------------------------------------------------------------------
-- Conferência: os números devem bater
-- customers 99441 | sellers 3095 | orders 99441
-- order_items 112650 | order_reviews 99224
-- ---------------------------------------------------------------------
SELECT 'customers' AS tabela, COUNT(*) AS linhas FROM customers
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews;
