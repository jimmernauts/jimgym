// vite.config.{ts,js}
import gleam from "vite-gleam";
import tailwindcss from "@tailwindcss/vite";
import Inspect from 'vite-plugin-inspect'

export default {
	plugins: [gleam(), tailwindcss(), Inspect()],
	test: {
		diff: {
			truncateThreshold: 10,
			expand: false,
		},
	},
};
