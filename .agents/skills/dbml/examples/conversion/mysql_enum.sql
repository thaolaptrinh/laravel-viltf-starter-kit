-- MySQL import quirks: ENUM(...) -> synthetic Enum; UNSIGNED is dropped; auto_increment -> [increment].
CREATE TABLE orders (
  id int unsigned auto_increment primary key,
  status enum('created', 'paid', 'shipped') not null,
  total decimal(10,2) not null
);
