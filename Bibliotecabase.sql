
CREATE DATABASE IF NOT EXISTS Biblioteca;
USE Biblioteca;


CREATE TABLE IF NOT EXISTS Auditoria (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tabela_nome VARCHAR(100),
    acao VARCHAR(20),
    registro_id INT,
    detalhes TEXT,
    efetuado_por INT,
    efetuado_em DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS Livros (
    id INT AUTO_INCREMENT PRIMARY KEY,
    titulo VARCHAR(255) NOT NULL,
    autor VARCHAR(255) NOT NULL,
    editora VARCHAR(255),
    genero VARCHAR(100),
    ano_publicacao INT,
    isbn VARCHAR(20) UNIQUE,
    quantidade_disponivel INT DEFAULT 0,
    valor DECIMAL(10,2)
);

CREATE TABLE IF NOT EXISTS Usuarios (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    cpf VARCHAR(20) UNIQUE NOT NULL,
    telefone VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS Funcionarios (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(255) NOT NULL,
    cargo VARCHAR(100),
    login VARCHAR(100) UNIQUE,
    senha_hash VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS Emprestimos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    livro_id INT NOT NULL,
    usuario_id INT NOT NULL,
    data_emprestimo DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_devolucao_prevista DATETIME NOT NULL,
    data_devolucao_real DATETIME,
    status ENUM('pendente','devolvido','atrasado') DEFAULT 'pendente',
    registrado_por INT,
    FOREIGN KEY (livro_id) REFERENCES Livros(id),
    FOREIGN KEY (usuario_id) REFERENCES Usuarios(id),
    FOREIGN KEY (registrado_por) REFERENCES Funcionarios(id)
);


CREATE INDEX idx_emprestimos_usuario ON Emprestimos(usuario_id);
CREATE INDEX idx_emprestimos_livro ON Emprestimos(livro_id);


INSERT IGNORE INTO Livros (titulo, autor, editora, genero, ano_publicacao, isbn, quantidade_disponivel, valor) VALUES
('1984','George Orwell','Companhia das Letras','Ficção',1949,'9780451524935',5,39.90),
('Clean Code','Robert C. Martin','Prentice Hall','Programação',2008,'9780132350884',2,129.90),
('Estruturas de Dados em C','Adam Drozdek','Bookman','Programação',2010,'9788573934462',3,89.50);

INSERT IGNORE INTO Usuarios (nome, email, cpf, telefone) VALUES
('João Silva','joao@example.com','111.111.111-11','(66) 99999-1111'),
('Maria Souza','maria@example.com','222.222.222-22','(66) 99999-2222');

INSERT IGNORE INTO Funcionarios (nome,cargo,login,senha_hash) VALUES
('Ana Paula','Bibliotecária','ana','$2y$10$exemploHashNaoReal'),
('Carlos Mendes','Atendente','carlos','$2y$10$exemploHashNaoReal2');


INSERT INTO Emprestimos (livro_id, usuario_id, data_emprestimo, data_devolucao_prevista, status, registrado_por)
VALUES (1, 1, NOW(), DATE_ADD(NOW(), INTERVAL 7 DAY), 'pendente', 1);

UPDATE Livros SET quantidade_disponivel = quantidade_disponivel - 1 WHERE id = 1;


CREATE OR REPLACE VIEW vw_livros_disponiveis AS
SELECT id, titulo, autor, editora, genero, ano_publicacao, isbn, quantidade_disponivel
FROM Livros
WHERE quantidade_disponivel > 0;

CREATE OR REPLACE VIEW vw_historico_emprestimos_usuario AS
SELECT e.id AS emprestimo_id, e.usuario_id, u.nome AS usuario_nome, e.livro_id, l.titulo,
       e.data_emprestimo, e.data_devolucao_prevista, e.data_devolucao_real, e.status, e.registrado_por
FROM Emprestimos e
JOIN Usuarios u ON e.usuario_id = u.id
JOIN Livros l ON e.livro_id = l.id;

CREATE OR REPLACE VIEW vw_emprestimos_vencidos AS
SELECT e.id, e.livro_id, l.titulo, e.usuario_id, u.nome AS usuario, e.data_emprestimo, e.data_devolucao_prevista
FROM Emprestimos e
JOIN Usuarios u ON e.usuario_id = u.id
JOIN Livros l ON e.livro_id = l.id
WHERE e.status = 'pendente' AND e.data_devolucao_prevista < NOW();


DELIMITER $$
CREATE PROCEDURE RegistrarEmprestimo (
    IN p_livro_id INT,
    IN p_usuario_id INT,
    IN p_funcionario_id INT,
    IN p_dias INT
)
BEGIN
    DECLARE v_qtd INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro ao registrar emprestimo';
    END;

    START TRANSACTION;

    SELECT quantidade_disponivel INTO v_qtd FROM Livros WHERE id = p_livro_id FOR UPDATE;
    IF v_qtd IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Livro nao encontrado';
    END IF;
    IF v_qtd <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Livro sem disponibilidade';
    END IF;

    INSERT INTO Emprestimos (livro_id, usuario_id, data_emprestimo, data_devolucao_prevista, status, registrado_por)
    VALUES (p_livro_id, p_usuario_id, NOW(), DATE_ADD(NOW(), INTERVAL p_dias DAY), 'pendente', p_funcionario_id);

    UPDATE Livros SET quantidade_disponivel = quantidade_disponivel - 1 WHERE id = p_livro_id;

    COMMIT;
END$$

CREATE PROCEDURE RegistrarDevolucao (
    IN p_emprestimo_id INT,
    IN p_funcionario_id INT
)
BEGIN
    DECLARE v_livro_id INT;
    DECLARE v_status VARCHAR(20);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Erro ao registrar devolucao';
    END;

    START TRANSACTION;

    SELECT livro_id, status INTO v_livro_id, v_status FROM Emprestimos WHERE id = p_emprestimo_id FOR UPDATE;
    IF v_livro_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Emprestimo nao encontrado';
    END IF;


    UPDATE Emprestimos
    SET status = 'devolvido', data_devolucao_real = NOW()
    WHERE id = p_emprestimo_id;


    UPDATE Livros SET quantidade_disponivel = quantidade_disponivel + 1 WHERE id = v_livro_id;

    COMMIT;
END$$
DELIMITER ;


DELIMITER $$
CREATE TRIGGER trg_emprestimos_after_insert
AFTER INSERT ON Emprestimos
FOR EACH ROW
BEGIN
    INSERT INTO Auditoria (tabela_nome, acao, registro_id, detalhes, efetuado_por)
    VALUES ('Emprestimos', 'INSERT', NEW.id,
            CONCAT('Livro=',NEW.livro_id,', Usuario=',NEW.usuario_id,', Prev=',NEW.data_devolucao_prevista),
            NEW.registrado_por);
END$$

CREATE TRIGGER trg_emprestimos_after_update
AFTER UPDATE ON Emprestimos
FOR EACH ROW
BEGIN
    INSERT INTO Auditoria (tabela_nome, acao, registro_id, detalhes, efetuado_por)
    VALUES ('Emprestimos', 'UPDATE', NEW.id,
            CONCAT('Status de ', OLD.status, ' para ', NEW.status, '; Prev=',NEW.data_devolucao_prevista,', Real=',NEW.data_devolucao_real),
            NEW.registrado_por);
END$$

CREATE TRIGGER trg_emprestimos_after_delete
AFTER DELETE ON Emprestimos
FOR EACH ROW
BEGIN
    INSERT INTO Auditoria (tabela_nome, acao, registro_id, detalhes, efetuado_por)
    VALUES ('Emprestimos', 'DELETE', OLD.id,
            CONCAT('Excluido; Livro=',OLD.livro_id,', Usuario=',OLD.usuario_id),
            OLD.registrado_por);
END$$
DELIMITER ;id


SELECT * FROM vw_livros_disponiveis;

SELECT * FROM vw_historico_emprestimos_usuario;

SELECT * FROM vw_emprestimos_vencidos;

