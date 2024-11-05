import fs from "fs";
import path from "path";
import { parse } from "@babel/parser";
import traverse from "@babel/traverse";

import * as config from "../config/Config.res.mjs";
import * as targetsDB from "../db/TargetsDB.res.mjs";

const bufferDirPath = path.resolve("", config.Agent.dirName);

const scanFile = (filePath = "") => {
  try {
    const source = fs.readFileSync(filePath, "utf-8");
    const ast = parse(source, {
      sourceType: "module",
      plugins: ["typescript", "jsx"],
    });

    const bufferPath = filePath.replace(`${bufferDirPath}/`, "");
    const [repositoryName, ...relativePathParts] = bufferPath.split("/");
    const relativePath = relativePathParts.join("/");

    traverse.default(ast, {
      ImportDeclaration({ node }) {
        node.specifiers.forEach((specifier) => {
          const importPath = node.source.value;
          const isPackage = !/^[./]/.test(importPath);

          if (isPackage) {
            const moduleName = specifier.local.name;

            targetsDB.Insert.target(repositoryName, importPath, moduleName, relativePath);
          }
        });
      },
    });
  } catch (error) {
    console.error(`[error]: agent / parseTargets / scanFile`);
    console.error(`Error parsing file: ${filePath}`);
    console.error(error);
  }
};

const scanDirectory = (dirPath = "") => {
  const files = fs.readdirSync(dirPath);

  files.forEach((file) => {
    const joinedPath = path.join(dirPath, file);
    const stat = fs.statSync(joinedPath);

    if (stat.isDirectory()) {
      scanDirectory(joinedPath);
    } else if (/\.(ts|tsx|js|jsx)$/.test(file) && !file.endsWith(".d.ts")) {
      scanFile(joinedPath);
    }
  });
};

scanDirectory(bufferDirPath);
