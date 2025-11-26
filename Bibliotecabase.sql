CREATE DATABASE Biblioteca;

USE Biblioteca;

CREATE TABLE Livros (
    id INT AUTO_INCREMENT PRIMARY KEY,
    titulo VARCHAR(255) NOT NULL,
    autor VARCHAR(255) NOT NULL,
    ano_publicacao INT,
    genero VARCHAR(100),
    valor DECIMAL(10, 2)

);

CREATE TABLE Saidas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    livro_id INT,
    data_saida DATE,
    data_retorno DATE,
    FOREIGN KEY (livro_id) REFERENCES Livros(id)
);

CREATE TABLE Clientes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    telefone VARCHAR(20)
);

CREATE TABLE Funcionarios (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(255) NOT NULL,
    cargo VARCHAR(100),
    salario DECIMAL(10, 2)
);

CREATE TABLE Emprestimos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    data_saida DATE,
    data_retorno DATE,
    FOREIGN KEY (livro_id) REFERENCES Livros(id),
    FOREIGN KEY (Cliente_id) REFERENCES Clientes(id)
    Taxa DECIMAL (count())
    Multa DECIMAL(Livros valor)
);

CREATE TABLE Devolucoes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    devolução DATE NOT NULL,
    FOREIGN KEY (Emprestimo_id) REFERENCES Emprestimos(id)
);




