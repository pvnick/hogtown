#!/bin/bash

sudo wp search-replace hogtown-dev.paulnickerson.dev hogtowncatholic.org wp_options wp_snippets --export > dump.sql
