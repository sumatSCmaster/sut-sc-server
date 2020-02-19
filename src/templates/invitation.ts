export const getTemplate = (link: string): string => 
`<!DOCTYPE html>
<html>
  <head>
    <style>
      body {
        height: 500px;
        width: 100%;
        background-color: rgb(226, 222, 222);
        display: flex;
        flex-direction: column;
        align-items: center;
      }
      h2 {
        text-align: center;
      }
      a {
        color: white;
        font-weight: bold;
        outline: 0;
        border: none;
        background-color: #1890ff;
        font-size: 20px;
        padding: 15px 10px;
        border-radius: 10px;
        height: 30px;
        text-decoration: none;
      }
      a:hover {
        cursor: pointer;
      }
    </style>
  </head>
  <body>
    <h2>Crea tu cuenta en el Sistema de Gestión Estratégica haciendo click en el siguiente botón.</h2>
    <a href="${link}" target="_blank">Registrarse</a>
  </body>
</html>`