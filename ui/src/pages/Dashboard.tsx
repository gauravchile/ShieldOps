import GlassCard from "../components/GlassCard";
import ComplianceRadar from "../components/charts/ComplianceRadar";
import { motion } from "framer-motion";
import NeonText from "../components/NeonText";

export default function Dashboard() {
  const radar = [
    { name: "High", value: 5 },
    { name: "Medium", value: 12 },
    { name: "Low", value: 20 },
  ];
  return (
    <div className="p-6 space-y-6">
      <motion.h1
        initial={{ opacity: 0, y: -8 }}
        animate={{ opacity: 1, y: 0 }}
        className="text-3xl font-bold"
      >
        <NeonText>Security Overview</NeonText>
      </motion.h1>
      <GlassCard>
        <ComplianceRadar data={radar} />
      </GlassCard>
    </div>
  );
}
