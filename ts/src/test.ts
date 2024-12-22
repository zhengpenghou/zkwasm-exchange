//import initHostBind, * as hostbind from "./wasmbind/hostbind.js";
//import initHostBind, * as hostbind from "./wasmbind/hostbind.js";
import { Player} from "./api.js";
import {get_server_admin_key} from "zkwasm-ts-server/src/config.js";
let account = "12345";
let player = new Player(get_server_admin_key(), "http://localhost:3000");
async function main() {
  //let towerId = 10038n + y;
  let state = await player.getState();
  console.log(state);

  state = await player.register();
  console.log(state);

  state = await player.addToken(0n, "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266");
  console.log(state);

  state = await player.addToken(1n, "0x70997970C51812dc3A010C7d01b50e0d17dc79C8");
  console.log(state);

  state = await player.addMarket(0n, 1n);
  console.log(state);

  console.log("Deposit 10000 tokens to the player");
  state = await player.deposit("428c73246352807b9b31b84ff788103abc7932b72801a1b23734e7915cc7f610", 0n, 10000n);
  console.log(state);
}

main();

