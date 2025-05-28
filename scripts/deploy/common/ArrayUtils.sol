/// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.30;

function toArray(address a) pure returns (address[] memory array) {
    array = new address[](1);
    array[0] = a;
}

function toArray(address a1, address a2) pure returns (address[] memory array) {
    array = new address[](2);
    array[0] = a1;
    array[1] = a2;
}

function toArray(address a1, address a2, address a3) pure returns (address[] memory array) {
    array = new address[](3);
    array[0] = a1;
    array[1] = a2;
    array[2] = a3;
}

function toArray(address a1, address a2, address a3, address a4) pure returns (address[] memory array) {
    array = new address[](4);
    array[0] = a1;
    array[1] = a2;
    array[2] = a3;
    array[3] = a4;
}

function toArray(address a1, address a2, address a3, address a4, address a5) pure returns (address[] memory array) {
    array = new address[](5);
    array[0] = a1;
    array[1] = a2;
    array[2] = a3;
    array[3] = a4;
    array[4] = a5;
}

function toArray(address a1, address a2, address a3, address a4, address a5, address a6)
    pure
    returns (address[] memory array)
{
    array = new address[](6);
    array[0] = a1;
    array[1] = a2;
    array[2] = a3;
    array[3] = a4;
    array[4] = a5;
    array[5] = a6;
}

function toArray(address a1, address a2, address a3, address a4, address a5, address a6, address a7)
    pure
    returns (address[] memory array)
{
    array = new address[](7);
    array[0] = a1;
    array[1] = a2;
    array[2] = a3;
    array[3] = a4;
    array[4] = a5;
    array[5] = a6;
    array[6] = a7;
}

function toArray(bytes4 a) pure returns (bytes4[] memory array) {
    array = new bytes4[](1);
    array[0] = a;
}

function toArray(bytes4 a, bytes4 b) pure returns (bytes4[] memory array) {
    array = new bytes4[](2);
    array[0] = a;
    array[1] = b;
}

function toArray(bytes4 a, bytes4 b, bytes4 c) pure returns (bytes4[] memory array) {
    array = new bytes4[](3);
    array[0] = a;
    array[1] = b;
    array[2] = c;
}

function toArray(bytes4 a, bytes4 b, bytes4 c, bytes4 d) pure returns (bytes4[] memory array) {
    array = new bytes4[](4);
    array[0] = a;
    array[1] = b;
    array[2] = c;
    array[3] = d;
}

function toArray(bytes4 a, bytes4 b, bytes4 c, bytes4 d, bytes4 e) pure returns (bytes4[] memory array) {
    array = new bytes4[](5);
    array[0] = a;
    array[1] = b;
    array[2] = c;
    array[3] = d;
    array[4] = e;
}

function toArray(bytes4 a, bytes4 b, bytes4 c, bytes4 d, bytes4 e, bytes4 f) pure returns (bytes4[] memory array) {
    array = new bytes4[](6);
    array[0] = a;
    array[1] = b;
    array[2] = c;
    array[3] = d;
    array[4] = e;
    array[5] = f;
}
